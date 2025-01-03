# Cloud Project

## Purpose
This project demonstrates a simple pipeline setup to retrieve data from AWS Athena and push it to Snowflake. It highlights how to integrate these cloud services effectively for basic data operations.

## Tools and Libraries
The project uses:
- AWS Athena for querying data
- Snowflake for data storage and processing
- Python with libraries such as `boto3`, `pandas`, and `snowflake-connector-python`.

## Highlights
- Secure integration with AWS and Snowflake using Secrets Manager
- Simple and reusable internal Python module for pipeline operations (`src.utils`)
- Demonstrates a basic retrieve/push workflow

## Applications
This demo can serve as:
- A foundation for building more complex data processing pipelines
- An example for integrating Athena and Snowflake in real-world projects

The script for this demo can be found here: [aws_to_snowflake.py](./aws_to_snowflake.py).
