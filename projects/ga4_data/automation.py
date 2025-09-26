"""
Purpose:
    - This flow retrieves event-level data from GA4.
    - Dynamically identifies the segment of the user.
    - Tags each user with their segments, sends back the data to Google Cloud for further activation with third-party tools.
"""

from prefect import flow
from utils.utils_gcloud import query_data, write_data

from pathlib import Path
from typing import Dict, List
import pandas as pd
from prefect import flow, task, get_run_logger


@task
def query_to_df(sql_file: str) -> pd.DataFrame:
    """Load SQL and query data, return results in a df."""
    with open(sql_file, "r", encoding="utf-8") as f:
        sql = f.read()
    return query_data(sql)


@task
def split_by_segments(df: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """
    Detect unique values in 'User Segment' (because we can introduce new segments in the future).
    Return a dict of DataFrames for each segment for later upload.
    """
    if "User Segment" not in df.columns:
        raise ValueError('Expected column "User Segment" not found in query result.')

    def clean(segment: str) -> str:
        # for dataset names, let's get rid of spaces and uppercase symbols
        return segment.strip().lower().replace(" ", "_")

    # all possible segments
    unique_segments = sorted(df["User Segment"].dropna().unique())

    return {
        clean(seg): df[df["User Segment"] == seg].copy()
        for seg in unique_segments
    }

@task
def upload_segments(
    chunks: dict[str, pd.DataFrame],
    table_prefix: str,
    overwrite: bool = True,
) -> list[str]:
    """
    Upload each segment DataFrame to BigQuery.

    Args:
        chunks: dict of {clean_segment_name: DataFrame}
        table_prefix: e.g. "my_project.my_dataset"
        overwrite: True = WRITE_TRUNCATE, False = WRITE_APPEND

    Returns:
        List of table IDs created/updated in Google Cloud.
    """
    logger = get_run_logger() # to monitor execution
    uploaded: list[str] = [] # placeholder for IDs

    for seg_name, sdf in chunks.items():
        if sdf.empty:
            # filtered dataframes
            logger.warning(f"Segment '{seg_name}' has 0 rows. Skipping upload.")
            continue

        table_id = f"{table_prefix}.user_segment_{seg_name}"
        write_data(sdf, table_id, overwrite=overwrite)
        logger.info(f"Uploaded {len(sdf):,} rows to {table_id}")
        uploaded.append(table_id)

    if not uploaded:
        logger.warning("No segment tables were uploaded.")
    return uploaded


@flow(name="Split Users by Segment and Upload to BigQuery")
def segment_export_flow(
    sql_file: str = "sql/query3.sql",
    table_prefix: str = "sandbox-2-472920.user_segments",
    overwrite: bool = True,
) -> list[str]:

    logger = get_run_logger()
    df = query_to_df(sql_file)
    logger.info(f"Fetched {len(df):,} rows from query.")

    chunks = split_by_segments(df)
    logger.info(f"Detected segments: {list(chunks.keys())}")

    uploaded = upload_segments(chunks, table_prefix, overwrite)
    logger.info(f"Completed. Created/updated tables: {uploaded}")
    return uploaded


if __name__ == "__main__":
    segment_export_flow()