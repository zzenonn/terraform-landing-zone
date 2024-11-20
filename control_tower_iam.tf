# This file contains the IAM roles that are prerequisites for the Control Tower setup. The roles are created with the necessary permissions for Control Tower to function correctly. 

resource "aws_iam_role" "aws_control_tower_admin" {
  name = "AWSControlTowerAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "controltower.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_policy" "aws_control_tower_admin_policy" {
  name = "AWSControlTowerAdminPolicy"
  description      = "AWS Control Tower policy to manage AWS resources"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:DescribeAvailabilityZones"
      Resource = "*"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "aws_control_tower_admin_policy_attachment" {
  role       = aws_iam_role.aws_control_tower_admin.name
  policy_arn = aws_iam_policy.aws_control_tower_admin_policy.arn
}

resource "aws_iam_role_policy_attachment" "aws_control_tower_admin_service_policy_attachment" {
  role       = aws_iam_role.aws_control_tower_admin.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSControlTowerServiceRolePolicy"
}

resource "aws_iam_role" "aws_control_tower_cloudtrail_role" {
  name = "AWSControlTowerCloudTrailRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_policy" "aws_control_tower_cloudtrail_role_policy" {
  name = "AWSControlTowerCloudTrailRolePolicy"
  description      = "AWS CloudTrail assumes this role to create and publish CloudTrail logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:${data.aws_partition.current.partition}:logs:*:*:log-group:aws-controltower/CloudTrailLogs:*"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "aws_control_tower_cloudtrail_policy_attachment" {
  role       = aws_iam_role.aws_control_tower_cloudtrail_role.name
  policy_arn = aws_iam_policy.aws_control_tower_cloudtrail_role_policy.arn
}

resource "aws_iam_role" "aws_control_tower_config_aggregator_role" {
  name = "AWSControlTowerConfigAggregatorRoleForOrganizations"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "aws_control_tower_config_aggregator_policy_attachment" {
  role       = aws_iam_role.aws_control_tower_config_aggregator_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_iam_role" "aws_control_tower_stackset_role" {
  name = "AWSControlTowerStackSetRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudformation.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_policy" "aws_control_tower_stackset_role_policy" {
  name = "AWSControlTowerStackSetRolePolicy"
  description      = "AWS CloudFormation assumes this role to deploy stacksets in the shared AWS Control Tower accounts"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:${data.aws_partition.current.partition}:iam::*:role/AWSControlTowerExecution"
    }]
  })
  path = "/service-role/"
}

resource "aws_iam_role_policy_attachment" "aws_control_tower_stackset_policy_attachment" {
  role       = aws_iam_role.aws_control_tower_stackset_role.name
  policy_arn = aws_iam_policy.aws_control_tower_stackset_role_policy.arn
}