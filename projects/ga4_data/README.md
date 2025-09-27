# Google Merchandise Store project

## Purpose
This utilizes user engagement data from GA4 to segment users as New, Active, Dormant or Lost.
A sample automation pipeline is provided that classifies the users on a rolling daily basis.

## Tools and Libraries
The project uses:
- Gcloud for querying data
- Prefect for flow automation.

## Data Source
Raw data is available [here](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset) and can be accessed using a free tier Google Cloud account.
