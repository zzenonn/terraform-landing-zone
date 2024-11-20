# AWS Control Tower End User Usage Guide

This guide is intended for end users who are provisioned with AWS accounts under AWS Control Tower. It provides instructions on how to access and use the resources provided by AWS Control Tower, including Service Catalog products and account management. This guide **MAY BE SHARED to customers**.

## Table of Contents

[[_TOC_]]

## Accessing Your AWS Account

1. **Login to AWS Identity Center (AWS SSO)**: You will receive an email invitation to access AWS Identity Center (AWS SSO). Follow the instructions in the email to set up your account.

2. **Access AWS Console**: Once your account is set up, you can log in to the AWS Management Console via AWS Identity Center (AWS SSO) using the following URL:

    ```plaintext
    https://<your-sso-domain>.awsapps.com/start
    ```

3. **Select Your Account**: After logging in, you will see a list of AWS accounts and roles that you have access to. Select the appropriate account and role to access the AWS Management Console.

## Using AWS Identity Center (AWS SSO)

1. **Multi-Factor Authentication (MFA)**: AWS Identity Center (AWS SSO) may require you to set up Multi-Factor Authentication (MFA) for added security. Follow the on-screen instructions to configure MFA.

2. **Switching Roles**: If you have access to multiple roles within an account, you can switch roles by going back to the start URL, then selecting a different role.

3. The following groups in identity center are crucial:

    - **AWSControlTowerAdmins**: This group is reserved for administrators. Members have access to and control tower guardrails. [Workloads should not be deployed to the organization’s management account](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices_mgmt-acct.html#bp_mgmt-acct_avoid-deploying).
    
    - **AWSAccountFactory**: This group is intended for end users who need to provision AWS accounts and manage permissions across the entire organization through the Identity Center.
    
    - **WorkloadAdmins**: Members of this group are automatically granted administrator access to all workload accounts.

    **Important Notes**: 

    - **Mutual Exclusivity**: The groups are mutually exclusive, meaning that while a user might have permission to provision accounts (via the **AWSAccountFactory** group), they might not have administrative access to those accounts unless they are also part of the **WorkloadAdmins** group.
        
    - **Group Membership**: It is possible for a user to belong to multiple groups, depending on their role and responsibilities within the organization.



## Provisioning AWS Accounts with Control Tower

1. **Control Tower**: AWS Control Tower uses AWS Service Catalog behind the scenes with initial products that you can provision in your account.

2. **Access Control Tower**: To access the Service Catalog, navigate to the AWS Management Console and search for ["Control Tower"](https://ap-southeast-1.console.aws.amazon.com/controltower/home?region=ap-southeast-1#) in the search bar. You may also click the hyperlink in this item.

3. **Account Factory**: Click **Account Factory** on the left-hand side, then click **Create Account** on the upper right-hand side.

4. **Specifying Account Information**: 

   - **Account Email**: Enter an email address to create a new account in your landing zone. You can use **plus aliases** for the email (e.g., `yourname+accountalias@example.com`) to manage multiple accounts under a single email address. Alternatively, contact your internal IT admin to request a dedicated email address if preferred.
   
   - **Display Name**: Provide a name for the account as it will appear in AWS Control Tower. The display name must be unique and can only include letters, numbers, periods, dashes, underscores, and spaces. It must begin with a letter or number.

   - **IAM Identity Center User Email**: Designate an email for the IAM Identity Center user. This email must be between 6 and 64 characters long.

   - **IAM Identity Center User Name**: Provide the first and last name intended for creating an IAM Identity Center user.

   - **Organizational Unit**: Select the Organizational Unit (OU) where the new account will reside. The OUs are automatically configured to enable all the necessary controls for the account. A **Workloads** OU is provided by default, but you may [create additional OUs](https://docs.aws.amazon.com/controltower/latest/userguide/create-new-ou.html) from control tower.

5. **Account Factory Customization**: After specifying the account information, you may indicate your `catalog account id` to provision products via Account Factory Customization (AFC). Products meant for AFC are prefixed with `AFC` (e.g. AFC_AWSBudgetOnly). 

    You can customize the account using the following AFC products:

   ### AWS Budget Only

   This AFC product automatically sets up an AWS budget with notifications at 25% increments. The budget configuration is parameterized, allowing you to specify the budget amount and the email address to receive notifications.

   - **BudgetName**: The name of the budget. It is recommended to use the project name.
   - **BudgetAmount**: The total budget amount in USD.
   - **SubscriberEmail**: The email address to receive budget notifications.

   Notifications will be sent at the following thresholds:
   - 25%
   - 50%
   - 75%
   - 100%
   - 125%

   It is **highly recommended** that all new accounts at the very least use this product to minimize the chances of cost overruns.

   ### AWS Budget with EC2 Instance Stop/Start Automation

   This AFC product combines budget notifications with Lambda automation for stopping and starting EC2 instances based on a specified schedule.

   - **BudgetName**: The name of the budget. It is recommended to use the project name. 
   - **BudgetAmount**: The total budget amount in USD. Default is `100`.
   - **SubscriberEmail**: The email address to receive budget notifications.
   - **ResourceGroupName**: The name of the resource group for EC2 automation. Default is `NonProdInstances`.
   - **ResourceGroupKey**: The key of the resource group tag. Default is `Type`.
   - **ResourceGroupValue**: The value of the resource group tag. Default is `NonProd`.
   - **StopInstanceCron**: The cron expression for when to stop your instances. Must be in UTC format. Default is `0 12 ? * * *` (8 PM UTC+8).
   - **StartInstanceCron**: The cron expression for when to start your instances. Must be in UTC format. Default is `0 0 ? * * *` (8 AM UTC+8).
   - **PythonRuntime**: The Lambda Python runtime version. Must start with `python3`. Default is `python3.12`.

   This product will:
   - Create a budget with notifications at 25%, 50%, 75%, 100%, and 125% thresholds.
   - Automatically stop EC2 instances based on the specified cron schedule using a Lambda function and AWS Event Bridge.
   - Automatically start EC2 instances based on the specified cron schedule using a Lambda function and AWS Event Bridge.
