# Load libraries
import os
import pandas as pd
import matplotlib.pyplot as plt

# Load datasets
def load_data():
    os.chdir('projects/subscription_revenue')
    company_data = pd.read_csv("raw_data/company_data.csv")
    user_data = pd.read_csv("raw_data/user_data.csv")
    account_management_data = pd.read_csv("raw_data/account_management_data.csv")

    return company_data, user_data, account_management_data

# Shorten Contract Dates (no need for timestamps)
def preprocess_company_data(company_data):
    company_data["Contract Start"] = pd.to_datetime(company_data["Contract Start"]).dt.date
    company_data["Contract End"] = pd.to_datetime(company_data["Contract End"]).dt.date
    return company_data

# Add fields useful for analysis: Account Manager
def merge_data(company_data, account_management_data, user_data):
    merged_data = company_data.merge(account_management_data, on="Company ID", how="left")
    user_counts = user_data.groupby(["Company ID", "Contract ID"]).size().reset_index(name="User Count")
    merged_data = merged_data.merge(user_counts, on=["Company ID", "Contract ID"], how="left")
    merged_data["User Count"] = merged_data["User Count"].fillna(0).astype(int)
    return merged_data

# Save processed dataset to csv
def save_data(data, file_path):
    data.to_csv(file_path, index=False)

# Main flow
def process_data_pipeline():
    # Fetch raw datasets
    company_data, user_data, account_management_data = load_data()

    # Process datasets to answer Question 1 (Revenue Analysis)
    company_data = preprocess_company_data(company_data)
    revenue_analysis = merge_data(company_data, account_management_data, user_data)

    # Export results
    output_path = "output/revenue_analysis.csv"
    save_data(revenue_analysis, output_path)
    print("The combined dataset has been saved in", output_path)

if __name__ == "__main__":
    process_data_pipeline()