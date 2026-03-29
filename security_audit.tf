

# ==========================================
# GuardDuty
# ==========================================

resource "aws_guardduty_detector" "guard_duty_main" {
  status = "ENABLED"
}


resource "aws_guardduty_detector" "guard_duty_delegated_administrator" {
  provider = aws.security_account

  enable = true

  datasources {
    s3_logs {
      enable = false
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false
        }
      }
    }
  }

  depends_on = [aws_guardduty_organization_admin_account.guard_duty_delegated_administrator]
}

resource "aws_guardduty_organization_admin_account" "guard_duty_delegated_administrator" {
  admin_account_id = var.security_account_id

  depends_on = [aws_guardduty_detector.guard_duty_main, aws_organizations_organization.organization]
}


resource "aws_guardduty_organization_configuration" "guard_duty" {
  provider = aws.security_account

  auto_enable_organization_members = "ALL"

  detector_id = aws_guardduty_detector.guard_duty_delegated_administrator.id

  # Expensive because of the volume of logs. Enable only if needed
  feature {
    name        = "S3_DATA_EVENTS"
    auto_enable = "NONE"
  }

  feature {
    name        = "EKS_AUDIT_LOGS"
    auto_enable = "ALL"
  }

  # Expensive. Enable only if needed
  feature {
    name        = "EBS_MALWARE_PROTECTION"
    auto_enable = "NONE"
  }

  depends_on = [aws_guardduty_organization_admin_account.guard_duty_delegated_administrator]
}



# ==========================================
# Security Hub
# ==========================================


resource "aws_securityhub_account" "security_hub_main" {}

resource "aws_securityhub_organization_admin_account" "security_hub" {
  admin_account_id = var.security_account_id

  depends_on = [aws_securityhub_account.security_hub_main, aws_organizations_organization.organization]
}

resource "aws_securityhub_account" "security_hub_delegated_administrator" {
  provider = aws.security_account

  depends_on = [aws_securityhub_organization_admin_account.security_hub]
}


resource "aws_securityhub_finding_aggregator" "security_hub_agg" {
  provider     = aws.security_account
  linking_mode = "ALL_REGIONS"

  depends_on = [aws_securityhub_account.security_hub_delegated_administrator]
}


resource "aws_securityhub_organization_configuration" "security_hub_config" {
  provider              = aws.security_account
  auto_enable_standards = "NONE"
  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [aws_securityhub_finding_aggregator.security_hub_agg]
}



# ==========================================
# IAM Access Analyzer
# ==========================================

resource "aws_accessanalyzer_analyzer" "organization_analyzer" {
  analyzer_name = "OrganizationAnalyzer"
  type          = "ORGANIZATION"

  depends_on = [aws_organizations_organization.organization]
}
