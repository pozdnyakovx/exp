import boto3
import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas


# Secrets Manager
# It contains AWS credentials to be used in helper functions
def get_secrets():
    """Retrieve secrets from AWS Secrets Manager."""
    client = boto3.client('secretsmanager')
    try:
        response = client.get_secret_value(SecretId='your_secrets_manager_name')
        return eval(response['SecretString'])
    except Exception as e:
        raise Exception(f"Failed to retrieve secrets: {str(e)}")


# Store secrets in the variable
secrets = get_secrets()


# Query Athena Database
def query_athena(database, output_bucket, query):
    """Run a query in AWS Athena and return the result as a Pandas DataFrame."""
    client = boto3.client('athena')

    # Start the query execution
    response = client.start_query_execution(
        QueryString=query,
        QueryExecutionContext={
            'Database': database
        },
        ResultConfiguration={
            'OutputLocation': output_bucket
        }
    )

    query_execution_id = response['QueryExecutionId']

    # Wait for the query to complete
    while True:
        status = client.get_query_execution(QueryExecutionId=query_execution_id)['QueryExecution']['Status']['State']
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break

    if status != 'SUCCEEDED':
        raise Exception(f"Athena query failed with status: {status}")

    # Get the query results
    result_location = f"{output_bucket}{query_execution_id}.csv"
    df = pd.read_csv(result_location)
    return df


# Push DataFrame to Snowflake
def push_to_snowflake(df, secrets, table_name, schema_name, database, warehouse):
    """Push a Pandas DataFrame to Snowflake."""
    conn = snowflake.connector.connect(
        account=secrets['SNOWFLAKE_ACCOUNT'],
        user=secrets['SNOWFLAKE_USER'],
        password=secrets['SNOWFLAKE_PASSWORD'],
        warehouse=warehouse,
        database=database,
        schema=schema_name
    )

    try:
        success, num_rows, _ = write_pandas(conn, df, table_name)
        if not success:
            raise Exception("Failed to write data to Snowflake.")

        print(f"Successfully inserted {num_rows} rows into {schema_name}.{table_name}.")
    finally:
        conn.close()
