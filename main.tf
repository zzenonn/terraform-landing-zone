resource "aws_servicecatalog_organizations_access" "enabled" {
  enabled = "true"
}

resource "aws_organizations_account" "logging_account" {
  name              = var.logging_account_name
  email             = var.logging_account_email
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = true

  lifecycle {
    ignore_changes = [
      role_name
    ]
  }

}

resource "aws_organizations_account" "security_account" {
  name              = var.security_account_name
  email             = var.security_account_email
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = true
  lifecycle {
    ignore_changes = [
      role_name
    ]
  }
}

# Catalog account
resource "aws_organizations_account" "catalog_account" {
  name              = var.catalog_account_name
  email             = var.catalog_account_email
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = true
  lifecycle {
    ignore_changes = [
      role_name
    ]
  }
}

resource "aws_organizations_delegated_administrator" "catalog_delegated_administrator" {
  account_id        = aws_organizations_account.catalog_account.id
  service_principal = "servicecatalog.amazonaws.com"
  depends_on        = [aws_servicecatalog_organizations_access.enabled]
}

resource "aws_kms_key" "logging_key" {
  description             = "KMS key for centralized logging"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "key-policy",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow use of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${aws_organizations_account.logging_account.id}:root",
            aws_iam_role.aws_control_tower_admin.arn
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${aws_organizations_account.logging_account.id}:root"
        },
        "Action" : [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      },
      {
        "Sid" : "Allow Config to use KMS for encryption",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "config.amazonaws.com"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow CloudTrail to use KMS for encryption",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceArn" : "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/aws-controltower-BaselineCloudTrail"
          },
          "StringLike" : {
            "kms:EncryptionContext:aws:cloudtrail:arn" : "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        "Sid" : "AllowGuardDutyKey",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "guardduty.amazonaws.com"
        },
        "Action" : "kms:GenerateDataKey",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : "${aws_organizations_account.security_account.id}",
            "aws:SourceArn" : "${aws_guardduty_detector.guard_duty_delegated_administrator.arn}"	
          }
        }
      }
    ]
  })
}



resource "aws_controltower_landing_zone" "landing_zone" {
  manifest_json = jsonencode({
    "governedRegions" : local.all_regions, # Note: You need to enable Region deny control manually in the AWS Control Tower console.
    "organizationStructure" : {
      "security" : {
        "name" : var.security_account_name,
      },
      "sandbox" : {
        "name" : var.sandbox_ou_name
      }
    },
    "centralizedLogging" : {
      "accountId" : aws_organizations_account.logging_account.id,
      "configurations" : {
        "loggingBucket" : {
          "retentionDays" : var.logging_bucket_retention_days
        },
        "accessLoggingBucket" : {
          "retentionDays" : var.access_logging_retention_days
        },
        "kmsKeyArn" : aws_kms_key.logging_key.arn
      },
      "enabled" : true
    },
    "securityRoles" : {
      "accountId" : aws_organizations_account.security_account.id,
    },
    "accessManagement" : {
      "enabled" : true
    }
  })

  # Ignore manifest_json changes because even if there are no changes, Terraform will try to update the resource.
  # Uncomment if there is a real update to the manifest_json.
  lifecycle {
    ignore_changes = [
      manifest_json
    ]
  }

  version = var.landing_zone_version

  depends_on = [
    aws_iam_role_policy_attachment.aws_control_tower_admin_policy_attachment,
    aws_iam_role_policy_attachment.aws_control_tower_admin_service_policy_attachment,
    aws_iam_role_policy_attachment.aws_control_tower_cloudtrail_policy_attachment,
    aws_iam_role_policy_attachment.aws_control_tower_config_aggregator_policy_attachment,
    aws_iam_role_policy_attachment.aws_control_tower_stackset_policy_attachment
  ]

}