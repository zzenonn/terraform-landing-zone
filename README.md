
# Terraform AWS Control Tower Setup

This Terraform project is designed to set up the necessary AWS resources, IAM roles, and Service Catalog portfolios for AWS Control Tower. The setup includes creating AWS Organizations accounts, IAM roles, KMS keys, deploying the AWS Control Tower landing zone, and setting up Service Catalog portfolios for Account Factory Customization (AFC) and utility products.

## Table of Contents

[[_TOC_]]

## Prerequisites

Before running this Terraform project, ensure that you have the following:

- An AWS account with the necessary permissions to create IAM roles, AWS Organizations accounts, KMS keys, and Service Catalog portfolios.
- Terraform installed on your local machine.
- An EXISTING AWS organization in the management account.

## Resources

### IAM Roles

The following IAM roles are created as prerequisites for AWS Control Tower:

- **AWSControlTowerAdmin**: This role is used by AWS Control Tower to manage your AWS environment.
- **AWSControlTowerCloudTrailRole**: This role is used by AWS CloudTrail for logging purposes.
- **AWSControlTowerConfigAggregatorRoleForOrganizations**: This role is used by AWS Config for aggregating configuration data across your organization.
- **AWSControlTowerStackSetRole**: This role is used by AWS CloudFormation StackSets for deploying resources across multiple accounts.
- **AWSControlTowerBlueprintAccess**: This role is used by AWS Control Tower Account Factory Customization (AFC) to access Service Catalog products.

### AWS Organizations Accounts

Three AWS Organizations accounts are created:

- **Logging Account**: Centralized logging account for storing logs.
- **Security Account**: Account for managing security roles and policies.
- **Catalog Account**: Account for storing Service Catalog portfolios for end-user provisioning.

### KMS Key

A KMS key is created for centralized logging purposes. The key is used to encrypt and decrypt logs stored in the logging account.

### AWS Control Tower Landing Zone

The AWS Control Tower landing zone is deployed using the `aws_controltower_landing_zone` resource. This sets up the necessary governance and security controls across your AWS environment.

### Service Catalog Portfolios

Two Service Catalog portfolios are created:

- **AFC Products Portfolio**: Contains products that are meant to be used with Control Tower Account Factory Customization (AFC).
- **Utility Products Portfolio**: Contains utility products that can help administer one or more AWS accounts.

### Lambda Functions

Two Lambda functions are created:

- **AttachWorkloadPermissionSets**: Automatically attaches the Admin permission set to workload administrators when a new account is created in the Workloads OU.
- **BlockControlTowerAdmin**: Blocks unauthorized modifications to the AWSControlTowerAdmins group in AWS Identity Center.

### EventBridge Rules

EventBridge rules are created to trigger the Lambda functions based on specific events:

- **CreateAccountSucceeded**: Triggers the `AttachWorkloadPermissionSets` Lambda function when a new account is successfully created in AWS Organizations.
- **AddMemberToAdminGroup**: Triggers the `BlockControlTowerAdmin` Lambda function when a member is added to the AWSControlTowerAdmins group.

## Variables

The following variables are used in this Terraform project:

- **profile**: The profile setup by your local AWS credentials using `aws configure` or `aws configure --profile client_name`. Default is `default`.
- **region**: The AWS region where resources will be deployed. Default is `ap-southeast-1`.
- **landing_zone_version**: The version of the AWS Control Tower landing zone to deploy. Default is `3.3`.
    - **IMPORTANT NOTE:** You must always use the latest version of the landing zone schema, or the deployment will fail. Refer to the [AWS Control Tower documentation](https://docs.aws.amazon.com/controltower/latest/userguide/landing-zone-schemas.html) for more information. As of the time of writing, `3.3` is the latest.
- **governed_regions**: List of AWS regions governed by Control Tower. Default is `["ap-northeast-2"]`.
- **logging_account_email**: Email address for the centralized logging account.
- **logging_account_name**: Name of the centralized logging account. Default is `CentralizedLogging`.
- **security_account_email**: Email address for the security roles account.
- **security_account_name**: Name of the security roles account. Default is `AuditAndSecurity`.
- **catalog_account_email**: Email address for the catalog account.
- **catalog_account_name**: Name of the catalog account. Default is `CatalogAccount`.
- **sandbox_ou_name**: Name of the sandbox Organizational Unit (OU). Default is `Workloads`.
- **logging_bucket_retention_days**: Number of days to retain logs. Default is `365` or 1 year.
- **access_logging_retention_days**: Number of days to retain access logs. Default is `3650` or 10 years.
- **lambda_runtime**: The runtime environment for Lambda functions. Default is `python3.12`.

## Outputs

The following outputs are provided by this Terraform project:

- **log_account_id**: The ID of the centralized logging account.
- **security_account_id**: The ID of the security roles account.
- **catalog_account_id**: The ID of the catalog account.

## Provider Configuration

The AWS provider is configured with the following settings:

```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}
```

Use your own profile as necessary. The profile defaults to `default`.

## Notes

- **Region Deny Control**: You need to enable Region deny control manually in the AWS Control Tower console. This is not handled by Terraform.
- **Changes to Manifest**: By default, the Control Tower block will ignore manifest changes because Terraform will attempt to update even if there's no actual change. If there is an actual change, comment out the lifecycle block.

---

Make sure to review and customize the variables to fit your specific requirements before deploying.

## Troubleshooting and Cleanup

If, for any reason, the landing zone fails to create, it is recommended to fix any errors and then run the following command:

```bash
terraform apply -replace aws_controltower_landing_zone.landing_zone -refresh=false
```

A failed landing zone will not be able to update the state properly, so skipping the refresh is required. **Organizational Units (OUs), Stacks, and StackSets need to be deleted manually.**

For stacks and stack sets, you can use the `delete_aws_control_tower_stacks.sh` script for easier deletion. Additionally, you need to **enter the logging account** and manually delete the S3 buckets.

The cleanup steps must be accomplished in this specific order:

1. Delete stacks and stack sets by running the `delete_aws_control_tower_stacks.sh` script.
2. Move the **Security** and **Logging Accounts** out of their respective OUs.
3. Delete the **Workload** OU and the **Security and Logging** OU.
4. Log in to the **logging account** and delete the S3 buckets manually.
5. Attempt to recreate the control tower by running:

```bash
terraform apply -replace aws_controltower_landing_zone.landing_zone -refresh=false
```

## Usage Guides

For more detailed instructions on how to use this Terraform project and AWS Control Tower, refer to the following guides:

- [Novare Engineer Deployment Guide](deployment_guide.md): A guide for Novare cloud engineers to setup the AWS Control Tower by Novare.
- [Customer End User Usage Guide](end_user_usage_guide.md): A guide for end users who are provisioned with AWS accounts under AWS Control Tower. **This may still be useful for Novare for post setup.**