# Helper module to query/write back functionality from Google Cloud 

from google.cloud import bigquery
import pandas as pd

# Initialize client
client = bigquery.Client()

def query_data(sql: str) -> pd.DataFrame:
    """
    Run a SQL query in BigQuery and return the result as a pandas DataFrame.
    """
    return client.query(sql).to_dataframe()

def write_data(df: pd.DataFrame, table_id: str, overwrite: bool = False) -> None:
    """
    Write a pandas DataFrame to a BigQuery table.

    Args:
        df: The DataFrame to upload.
        table_id: Fully-qualified table name, e.g. "my_project.my_dataset.my_table".
        overwrite: Replace the table if True, otherwise append.
    """
    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE" if overwrite else "WRITE_APPEND"
    )
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Wait for the job to finish
    print(f"Data written to {table_id}")
