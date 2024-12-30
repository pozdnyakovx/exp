# Business Case and Dataset Description

## Business Case

Imagine a SaaS company **FlowForce** providing an accounting and CRM platform tailored for small businesses. The platform operates on a subscription model, offering three tiers of service to meet the varying needs of clients:

1. **Tier 1**: Basic functionalities for startups.
2. **Tier 2**: Intermediate features for growing businesses.
3. **Tier 3**: Advanced features for established businesses.

The datasets simulate real-world scenarios for managing and analyzing customer data, user activity, and financial performance, enabling the development of predictive models, business intelligence dashboards, and CRM tools. Below is a description of datasets that can be used to analyze the state of the business.

## Dataset Descriptions

### 1. **Company Data**
Contains information about client companies and their subscriptions.

**Columns:**
- `Company Name`: The name of the client company.
- `Company ID`: A unique identifier for the company.
- `Country`: The country where the company is located.
- `Contract ID`: A unique identifier for the company's contract.
- `Previous Contract ID`: Links to the previous contract if the contract is a renewal.
- `Contract Start`: The start date of the contract.
- `Contract End`: The end date of the contract.
- `Subscription Tier`: The tier of subscription (Tier 1, Tier 2, Tier 3).
- `Price of Subscription`: The price of the subscription based on the tier.

### 2. **User Data**
Maps users to their respective companies and contracts.

**Columns:**
- `Company ID`: Links the user to the respective company.
- `Contract ID`: Links the user to the respective contract.
- `User Email`: The email address of the user.
- `User ID`: A unique identifier for the user.

### 3. **Account Management Data**
Tracks account owners responsible for managing client relationships.

**Columns:**
- `Company ID`: Links the account owner to the respective company.
- `Account Owner Name`: The name of the account owner.

### 4. **User Activity Data**
Logs event-level activity data for users over the past year.

**Columns:**
- `User ID`: Links activity to the respective user.
- `Date`: The date of the activity (pageview).

## Project Goal
Let's use these datasets to generate some insights about the company's state of business. We'll look at the financial metrics, engagement levels, and account management data. Below are some business questions that we're aiming to answer:

1. **Revenue Analysis:**
   - How much revenue does each subscription tier generate for the company?
   - Which Account Manager is the best performer in terms of revenue generation?
   - What are the revenue trends by geography?

2. **User Engagement:**
   - How large is the user base for each subscription tier?
   - How engaged are the users? What are the patterns in their activity levels?

3. **Client Retention:**
   - What is the overall renewal rate for the company?
   - Which subscription tier and subcription price has the best renewal rates?


To answer the above questions, I have built a [**Looker dashboard**](https://lookerstudio.google.com/reporting/58cf6d9f-25bb-4dea-ae78-fe2fecfa2d49).