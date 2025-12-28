#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run the Airflow CLI with noisy deprecation warnings suppressed.
# Useful on Python 3.14 where Airflow 3.0.6 currently emits PendingDeprecationWarning
# from `airflow.cli.cli_config`.

export PYTHONWARNINGS="${PYTHONWARNINGS:-default}"

# Append a filter for the specific warning without disabling other warnings.
export PYTHONWARNINGS="${PYTHONWARNINGS},ignore:FileType is deprecated.*:PendingDeprecationWarning"

exec airflow "$@"

