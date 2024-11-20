
# This file is for a Lambda function that listens 
# for create account events in AWS Organizations and 
# attaches the Admin permission role to workload 
# administrators. Accounts must be created in the workloads OU.

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_directory_admin_role" {
  name = "AWSSSOLambdaDirectoryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AWSSSODirectoryAdministrator",
    "${aws_iam_policy.sso_create_account_assignment_policy.arn}"
  ]
}

# Create a custom IAM policy that allows the sso:CreateAccountAssignment action for managing permission sets
resource "aws_iam_policy" "sso_create_account_assignment_policy" {
  name        = "SSOCreateAccountAssignmentPolicy"
  description = "Allows the Lambda function to assign permission sets in AWS SSO"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "sso:CreateAccountAssignment",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Create an archive of the Python file
data "archive_file" "attach_permission_set_workload_ou_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/attach_permission_set_workload_ou.py"
  output_path = "${path.module}/.terraform/attach_permission_set_workload_ou.zip"
}

# Create a Lambda function that automatically attaches the Admin permission set to workload administrators
resource "aws_lambda_function" "attach_workload_permission_sets" {
  function_name = "AttachWorkloadPermissionSets"
  handler       = "attach_permission_set_workload_ou.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_directory_admin_role.arn

  filename = data.archive_file.attach_permission_set_workload_ou_lambda_zip.output_path

  environment {
    variables = {
      IDENTITY_CENTER_ARN = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
      PERMISSION_SET     = data.aws_ssoadmin_permission_set.admin.arn
      PRINCIPAL_ID       = aws_identitystore_group.workload_admins.group_id
      PRINCIPAL_TYPE     = "GROUP"
      TARGET_TYPE        = "AWS_ACCOUNT"
    }
  }

  source_code_hash = filebase64sha256("${path.module}/lambda_functions/attach_permission_set_workload_ou.py")
}

# Create an EventBridge rule
resource "aws_cloudwatch_event_rule" "create_managed_account_succeeded" {
  name        = "CreateManagedAccountSucceeded"
  description = "Triggers when a new managed account is successfully created via AWS Control Tower"
  event_pattern = jsonencode({
    "detail-type": ["AWS Service Event via CloudTrail"],
    source       = ["aws.controltower"],
    detail       = {
      serviceEventDetails = {
        createManagedAccountStatus = {
          state = ["SUCCEEDED"]
        }
      },
      eventName = ["CreateManagedAccount"]
    }
  })
}

# Create EventBridge target to trigger the Lambda function
resource "aws_cloudwatch_event_target" "permission_set_lambda_target" {
  rule      = aws_cloudwatch_event_rule.create_managed_account_succeeded.name
  target_id = "send_to_lambda"
  arn       = aws_lambda_function.attach_workload_permission_sets.arn
}

# Allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge_permission_set_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.attach_workload_permission_sets.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.create_managed_account_succeeded.arn
}

resource "aws_cloudwatch_event_rule" "add_member_to_admin_group" {
  name        = "AddMemberToAdminGroup"
  description = "Event Rule which will be triggered when the AWS SSO Permission Sets are created"
  event_pattern = jsonencode({
    source = [
      "aws.sso-directory"
    ]
    detail-type = [
      "AWS API Call via CloudTrail"
    ]
    detail = {
      "eventSource" : ["sso-directory.amazonaws.com"],
      "eventName" : ["AddMemberToGroup"]
    }
  })
}

# Create an archive of the Python file
data "archive_file" "block_control_tower_admin_group_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/block_control_tower_admin_group.py"
  output_path = "${path.module}/.terraform/block_control_tower_admin_group.zip"
}

# Create a Lambda function
resource "aws_lambda_function" "block_control_tower_admin" {
  function_name = "BlockControlTowerAdmin"
  handler       = "block_control_tower_admin_group.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_directory_admin_role.arn

  filename = data.archive_file.block_control_tower_admin_group_lambda_zip.output_path

  environment {
    variables = {
      IDENTITY_CENTER_ID = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
      CONTROL_TOWER_ADMIN_GROUP_ID     = data.aws_identitystore_group.control_admin_group.group_id
    }
  }

  source_code_hash = filebase64sha256("${path.module}/lambda_functions/block_control_tower_admin_group.py")
}

# Create EventBridge target to trigger the Lambda function
resource "aws_cloudwatch_event_target" "block_control_tower_admin_target" {
  rule      = aws_cloudwatch_event_rule.add_member_to_admin_group.name
  target_id = "send_to_lambda"
  arn       = aws_lambda_function.block_control_tower_admin.arn
}

# Allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge_block_control_tower_admin" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.block_control_tower_admin.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.add_member_to_admin_group.arn
}