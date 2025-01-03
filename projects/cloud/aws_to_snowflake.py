import pandas as pd
from src.utils import get_secrets, query_athena, push_to_snowflake  # Import helper functions from utils module

# AWS Athena Configuration
ATHENA_DATABASE = 'your_database'
ATHENA_OUTPUT_BUCKET = 's3://your-output-bucket/'
QUERY = """SELECT * FROM your_table LIMIT 100;"""

# Snowflake Configuration
SNOWFLAKE_TABLE = 'your_table'
SNOWFLAKE_SCHEMA = 'your_schema'
SNOWFLAKE_DATABASE = 'your_database'
SNOWFLAKE_WAREHOUSE = 'your_warehouse'

if __name__ == "__main__":
    # Retrieve Secrets from AWS
    print("Retrieving secrets...")
    secrets = get_secrets()

    # Retrieve data from an Athena table
    print("Querying Athena...")
    data = query_athena(ATHENA_DATABASE, ATHENA_OUTPUT_BUCKET, QUERY)

    # Format the data (if needed)
    # print("Formatting data...")
    # data.columns = [col.upper() for col in data.columns]  # Example: Make column names uppercase

    # Push the data to Snowflake
    print("Pushing data to Snowflake...")
    push_to_snowflake(data, secrets, SNOWFLAKE_TABLE, SNOWFLAKE_SCHEMA, SNOWFLAKE_DATABASE, SNOWFLAKE_WAREHOUSE)

    print("Data push complete.")
