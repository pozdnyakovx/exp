# Load libraries
import os
import pandas as pd

# Load datasets
def load_data():
    os.chdir('projects/subscription_revenue')
    company_data = pd.read_csv('raw_data/company_data.csv')
    user_data = pd.read_csv('raw_data/user_data.csv')
    account_management_data = pd.read_csv('raw_data/account_management_data.csv')
    user_activity_data = pd.read_csv('raw_data/user_activity_data.csv')

    return company_data, user_data, account_management_data, user_activity_data

# Shorten Contract Dates (no need for timestamps)
def preprocess_company_data(company_data):
    company_data['Contract Start'] = pd.to_datetime(company_data['Contract Start']).dt.date
    company_data['Contract End'] = pd.to_datetime(company_data['Contract End']).dt.date
    # Create a binary variable or renewal calculation
    company_data['Renewed'] = company_data['Previous Contract ID'].notnull().astype(int)

    return company_data

# Add fields useful for analysis: Account Manager
def merge_revenue_analysis(company_data, account_management_data, user_data):
    merged_data = company_data.merge(account_management_data, on='Company ID', how='left')
    user_counts = user_data.groupby(['Company ID', 'Contract ID']).size().reset_index(name='User Count')
    merged_data = merged_data.merge(user_counts, on=['Company ID', 'Contract ID'], how='left')
    merged_data['User Count'] = merged_data['User Count'].fillna(0).astype(int)

    return merged_data

# Merge user activity data with user data and company name
def merge_engagement_analysis(user_activity_data, user_data, company_data):
    # Add tier info to user data
    user_data_merged = user_data.merge(company_data[['Contract ID',
                                                    'Company Name',
                                                    'Country',
                                                    'Subscription Tier']], on='Contract ID', how='left')

    # Add fields indicating user activity patterns for each year 
    # Value of 1 indicates that a user was active at least once in the corresponding year
    user_activity_data['Date'] = pd.to_datetime(user_activity_data['Date'], errors='coerce')
    user_activity_data['Year'] = user_activity_data['Date'].dt.year
    for year in range(2020, 2024):
        user_data_merged[str(year)] = user_data_merged['User ID'].apply(
            lambda user_id: 1 if year in user_activity_data[user_activity_data['User ID'] == user_id]['Year'].values else 0
        )
    
    return user_data_merged

# Save processed dataset to csv
def save_data(data_dict):
    for file_path, data in data_dict.items():
        data.to_csv(file_path, index=False)
        print(f'Dataset saved at {file_path}')

# Main flow
def process_data_pipeline():
    # Fetch raw datasets
    company_data, user_data, account_management_data, user_activity_data = load_data()

    # Process datasets to answer Question 1 (Revenue Analysis)
    company_data = preprocess_company_data(company_data)
    revenue_analysis = merge_revenue_analysis(company_data, account_management_data, user_data)

    # Process datasets to answer Question 2 (Engagement Analysis)
    engagement_analysis = merge_engagement_analysis(user_activity_data, user_data, company_data)

    # Export results
    output_files = {
        'output/revenue_analysis.csv': revenue_analysis,
        'output/engagement_analysis.csv': engagement_analysis
    }
    save_data(output_files)
    # Question 3 (Renewal Analysis) will be answered in Looker using Custom Calculations

if __name__ == '__main__':
    process_data_pipeline()