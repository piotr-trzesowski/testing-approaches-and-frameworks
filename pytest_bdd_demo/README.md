pip install pytest pytest-bdd

Key Concepts

Feature files: Written in Gherkin language with .feature extension
Step definitions: Python functions that implement each step
Scenarios: Concrete examples of behavior
Fixtures: pytest fixtures (like the calculator in this example) can be used

This repo includes an Airflow DAG at `airflow/dags/pytest_bdd_runner_dag.py` that executes `pytest` for `pytest_bdd_demo/` and shows the output in Airflow task logs.
