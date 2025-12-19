"""Airflow DAG to run the local pytest-bdd suite.

How it's meant to be used
-------------------------
Run a standalone Airflow instance (typically via Docker) and mount this repo into
the container. Then trigger the DAG and read the pytest output from the task logs.

Recommended mount:
  /opt/airflow/repo  -> this git repo root

The DAG runs:
  python -m pytest -q
inside the `pytest_bdd/` folder.

Notes
-----
- This is intentionally a BashOperator so it works in a plain Airflow image.
- Install test deps in the container first (pytest, pytest-bdd).
"""

from __future__ import annotations

import os
from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

# Path inside the Airflow container where the repo is mounted.
REPO_DIR = os.environ.get("REPO_DIR", "/opt/airflow/repo")
PROJECT_DIR = os.path.join(REPO_DIR, "pytest_bdd")

with DAG(
    dag_id="run_pytest_bdd",
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=["tests", "pytest", "bdd"],
) as dag:
    run_pytest_bdd = BashOperator(
        task_id="pytest_bdd",
        env={
            "PROJECT_DIR": PROJECT_DIR,
            # Ensure the repo code is importable (calculator.py lives in PROJECT_DIR)
            "PYTHONPATH": PROJECT_DIR,
        },
        bash_command=(
            "set -euo pipefail; "
            "cd \"${PROJECT_DIR}\"; "
            "python -m pytest -q"
        ),
    )
