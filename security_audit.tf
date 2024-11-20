resource "aws_guardduty_detector" "guard_duty_main" {
  enable = true
}

resource "aws_securityhub_account" "security_hub_main" {}

provider "aws" {
  alias   = "security_account"
  region  = var.region
  profile = var.profile

  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.security_account.id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-session"
  }
}

resource "aws_guardduty_detector" "guard_duty_delegated_administrator" {
  provider = aws.security_account
}

resource "aws_guardduty_organization_admin_account" "guard_duty_delegated_administrator" {
  admin_account_id = aws_organizations_account.security_account.id
  depends_on       = [aws_guardduty_detector.guard_duty_delegated_administrator]
}


resource "aws_guardduty_organization_configuration" "guard_duty" {
  provider = aws.security_account

  auto_enable_organization_members = "ALL"

  detector_id = aws_guardduty_detector.guard_duty_delegated_administrator.id

  datasources {
    # Expensive because of the volume of logs. Enable only if needed
    s3_logs {
      auto_enable = false
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }

    # Expensive. Enable only if needed
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = false
        }
      }
    }
  }

  depends_on = [aws_guardduty_organization_admin_account.guard_duty_delegated_administrator]
}

resource "aws_guardduty_member" "catalog_account" {
  provider    = aws.security_account
  account_id  = aws_organizations_account.catalog_account.id
  detector_id = aws_guardduty_detector.guard_duty_delegated_administrator.id
  email       = var.catalog_account_email
#   invite = false

  # If invite is accepted, ig
  lifecycle {
    ignore_changes = [
      invite, email
    ]
  }
}

resource "aws_guardduty_member" "logging_account" {
  provider    = aws.security_account
  account_id  = aws_organizations_account.logging_account.id
  detector_id = aws_guardduty_detector.guard_duty_delegated_administrator.id
  email       = var.logging_account_email
#   invite = false

  lifecycle {
    ignore_changes = [
      invite, email
    ]
  }
}

resource "aws_securityhub_account" "security_hub_delegated_administrator" {
  provider                  = aws.security_account
  auto_enable_controls      = true
  control_finding_generator = "STANDARD_CONTROL"
  enable_default_standards  = false
}

resource "aws_securityhub_organization_admin_account" "security_hub" {
  admin_account_id = aws_organizations_account.security_account.id
  depends_on       = [aws_securityhub_account.security_hub_delegated_administrator]
}

resource "aws_securityhub_finding_aggregator" "security_hub_agg" {
  provider     = aws.security_account
  linking_mode = "ALL_REGIONS"

  depends_on = [aws_securityhub_organization_admin_account.security_hub]
}

resource "aws_securityhub_organization_configuration" "security_hub_config" {
  provider              = aws.security_account
  auto_enable           = false
  auto_enable_standards = "NONE"
  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [aws_securityhub_finding_aggregator.security_hub_agg]
}

provider "aws" {
  alias   = "logging_account"
  region  = var.region
  profile = var.profile

  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.logging_account.id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-session"
  }
}

# Create S3 Bucket for Guard duty logs templates
resource "aws_s3_bucket" "guard_duty_findings_logs" {
  provider      = aws.logging_account
  bucket = "aws-org-gd-finding-logs-${aws_organizations_account.logging_account.id}-${var.region}"
}

resource "aws_s3_bucket_lifecycle_configuration" "expire_after_defined_period" {
  provider = aws.logging_account
  bucket   = aws_s3_bucket.guard_duty_findings_logs.id

  rule {
    id     = "ExpireAfterDefinedPeriod"
    status = "Enabled"

    expiration {
      days = var.logging_bucket_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "guard_duty_findings_logs_policy" {
  provider = aws.logging_account
  bucket   = aws_s3_bucket.guard_duty_findings_logs.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowGuardDutygetBucketLocation",
        "Effect": "Allow",
        "Principal": {"Service": "guardduty.amazonaws.com"},
        "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
        "Resource": aws_s3_bucket.guard_duty_findings_logs.arn,
        "Condition": {
          "StringEquals": {
            "aws:SourceAccount": "${aws_organizations_account.security_account.id}",
            "aws:SourceArn": "${aws_guardduty_detector.guard_duty_delegated_administrator.arn}"
          }
        }
      },
      {
        "Sid": "AllowGuardDutyPutObject",
        "Effect": "Allow",
        "Principal": {"Service": "guardduty.amazonaws.com"},
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.guard_duty_findings_logs.arn}/*",
        "Condition": {
          "StringEquals": {
            "aws:SourceAccount": "${aws_organizations_account.security_account.id}",
            "aws:SourceArn": "${aws_guardduty_detector.guard_duty_delegated_administrator.arn}"
          }
        }
      },
      {
        "Sid": "DenyUnencryptedUploads",
        "Effect": "Deny",
        "Principal": {"Service": "guardduty.amazonaws.com"},
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.guard_duty_findings_logs.arn}/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption": "aws:kms"
          }
        }
      },
      {
        "Sid": "DenyIncorrectHeader",
        "Effect": "Deny",
        "Principal": {"Service": "guardduty.amazonaws.com"},
        "Action": "s3:PutObject",
        "Resource": "${aws_s3_bucket.guard_duty_findings_logs.arn}/*",
        "Condition": {
          "StringNotEquals": {
            "s3:x-amz-server-side-encryption-aws-kms-key-id": "${aws_kms_key.logging_key.arn}"
          }
        }
      },
      {
        "Sid": "DenyNon-HTTPS",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": "${aws_s3_bucket.guard_duty_findings_logs.arn}/*",
        "Condition": {
          "Bool": {"aws:SecureTransport": "false"}
        }
      }
    ]
  })
}

resource "aws_guardduty_publishing_destination" "centralized_logging" {
  provider = aws.security_account
  detector_id     = aws_guardduty_detector.guard_duty_delegated_administrator.id
  destination_arn = aws_s3_bucket.guard_duty_findings_logs.arn
  kms_key_arn     = aws_kms_key.logging_key.arn

  depends_on = [
    aws_s3_bucket_policy.guard_duty_findings_logs_policy,
  ]
}