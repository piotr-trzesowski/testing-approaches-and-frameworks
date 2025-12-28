#!/usr/bin/env bash
set -euo pipefail

# airflow not working on python 3.14 yet - use python 3.12

# Deterministic local Airflow 3 standalone runner using SimpleAuthManager.
# - forces AIRFLOW_HOME under the repo (so airflow.cfg/db/logs don't end up in ~/airflow)
# - ensures admin/admin exists for /auth/token (creates password hash file)
# - forces the auth manager + user list via env vars to avoid "wrong airflow.cfg" confusion
# - runs a smoke test against POST /auth/token and exits early with diagnostics if it fails
#
# Usage:
#   source .venv/bin/activate
#   bash airflow/run_airflow3_standalone_local.sh
#
# Optional:
#   AIRFLOW_RESET=1 bash airflow/run_airflow3_standalone_local.sh   # wipes AIRFLOW_HOME before start

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AIRFLOW_HOME="${AIRFLOW_HOME:-$ROOT_DIR/.airflow-home}"

PASSWORDS_FILE="$AIRFLOW_HOME/simple_auth_manager_passwords.json.generated"

# Force SimpleAuthManager (Airflow 3)
export AIRFLOW__CORE__AUTH_MANAGER="airflow.api_fastapi.auth.managers.simple.simple_auth_manager.SimpleAuthManager"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS="admin:admin"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_ALL_ADMINS="False"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE="$PASSWORDS_FILE"

# Airflow sometimes binds UI + api-server; keep default port here.
AIRFLOW_URL="http://localhost:8080"

echo "AIRFLOW_HOME=$AIRFLOW_HOME"
echo "SIMPLE_AUTH_MANAGER_PASSWORDS_FILE=$PASSWORDS_FILE"

if [[ "${AIRFLOW_RESET:-0}" == "1" ]]; then
  echo "AIRFLOW_RESET=1 -> wiping $AIRFLOW_HOME"
  rm -rf "$AIRFLOW_HOME"
fi
mkdir -p "$AIRFLOW_HOME"


# Ensure airflow.cfg exists in this AIRFLOW_HOME (helps debugging)
airflow info >/dev/null 2>&1 || true

# Generate password hash file with admin/admin
python "$ROOT_DIR/airflow/bootstrap_simple_auth.py" \
  --airflow-home "$AIRFLOW_HOME" \
  --passwords-file "$PASSWORDS_FILE" \
  --username admin \
  --password admin

echo "Password file created at: $PASSWORDS_FILE"
if [[ -f "$PASSWORDS_FILE" ]]; then
  head -n 5 "$PASSWORDS_FILE" || true
else
  echo "ERROR: password file was not created."
  exit 1
fi

# Best-effort cleanup: if something is already listening on 8080, stop it.
if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port 8080 is already in use; attempting to stop existing Airflow processes..."
    pkill -f "airflow standalone" >/dev/null 2>&1 || true
    pkill -f "airflow api-server" >/dev/null 2>&1 || true
    pkill -f "airflow scheduler" >/dev/null 2>&1 || true
    sleep 2
  fi
fi

# Start Airflow in the background so we can smoke-test token auth.
LOG_FILE="$AIRFLOW_HOME/standalone.out.log"
echo "Starting airflow standalone (login/token: admin/admin)"
echo "Logs: $LOG_FILE"
( airflow standalone >"$LOG_FILE" 2>&1 ) &
AIRFLOW_PID=$!

cleanup() {
  if kill -0 "$AIRFLOW_PID" >/dev/null 2>&1; then
    echo "Stopping Airflow (pid $AIRFLOW_PID)"
    kill "$AIRFLOW_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Wait for the API to come up and smoke-test /auth/token
attempt_token() {
  curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$AIRFLOW_URL/auth/token" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin"}'
}

echo "Waiting for Airflow to start..."
for i in $(seq 1 30); do
  code="$(attempt_token || true)"
  if [[ "$code" == "201" ]]; then
    echo "OK: /auth/token returned 201 (admin/admin works)."
    echo "Open UI: $AIRFLOW_URL"
    echo "Airflow is running in background (pid $AIRFLOW_PID)."
    echo "To stop: kill $AIRFLOW_PID"
    trap - EXIT
    exit 0
  fi
  sleep 1
  if ! kill -0 "$AIRFLOW_PID" >/dev/null 2>&1; then
    echo "ERROR: Airflow process exited early. Last logs:"
    tail -n 80 "$LOG_FILE" || true
    exit 1
  fi
  if [[ "$i" == "10" || "$i" == "20" ]]; then
    echo "...still starting (attempt $i/30), last logs:"
    tail -n 20 "$LOG_FILE" || true
  fi
  # if code is 401, keep waiting a bit; it can happen briefly during startup

done

echo "ERROR: Airflow did not become ready within 30s. Last logs:"
tail -n 120 "$LOG_FILE" || true
exit 1
