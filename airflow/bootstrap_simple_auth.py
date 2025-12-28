"""Bootstrap Airflow 3 SimpleAuthManager credentials.

Problem this solves
-------------------
Airflow 3.0.6 SimpleAuthManager stores passwords in a JSON file under
AIRFLOW_HOME (by default `simple_auth_manager_passwords.json.generated`).

IMPORTANT: In Airflow 3.0.6 the password check is a direct string comparison
(passwords[username] == provided_password). There is no hashing.

This script makes local development deterministic by ensuring `admin/admin`
exists in the password file.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def _load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except Exception:
        # If file is corrupted, don't crash; recreate.
        return {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Bootstrap Airflow SimpleAuthManager passwords")
    parser.add_argument("--airflow-home", default=os.environ.get("AIRFLOW_HOME"), help="AIRFLOW_HOME directory")
    parser.add_argument("--passwords-file", default=None, help="Override passwords json file path")
    parser.add_argument("--username", default="admin")
    parser.add_argument("--password", default="admin")
    args = parser.parse_args()

    if not args.airflow_home and not args.passwords_file:
        raise SystemExit("Set AIRFLOW_HOME or pass --airflow-home/--passwords-file")

    airflow_home = Path(args.airflow_home).expanduser().resolve() if args.airflow_home else None

    passwords_file = (
        Path(args.passwords_file).expanduser().resolve()
        if args.passwords_file
        else (airflow_home / "simple_auth_manager_passwords.json.generated")
    )

    passwords_file.parent.mkdir(parents=True, exist_ok=True)

    data = _load_json(passwords_file)

    # Airflow 3.0.6 expects plaintext values in this JSON file.
    data[str(args.username)] = str(args.password)

    passwords_file.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")

    print(f"Wrote: {passwords_file}")
    print(f"Users in file: {', '.join(sorted(data.keys()))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

