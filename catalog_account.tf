provider "aws" {
  alias   = "catalog_account"
  region  = var.region
  profile = var.profile

  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.catalog_account.id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-session"
  }
}

resource "aws_iam_role" "aws_control_tower_blueprint_access_role" {
  provider = aws.catalog_account
  name     = "AWSControlTowerBlueprintAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSServiceCatalogAdminFullAccess"
  ]
}

# Create S3 Bucket to house CloudFormation templates
resource "aws_s3_bucket" "service_catalog_products" {
  provider      = aws.catalog_account
  bucket_prefix = "novare-catalog-utlity"
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

resource "aws_s3_bucket_versioning" "service_catalog_versioning" {
  provider = aws.catalog_account
  bucket   = aws_s3_bucket.service_catalog_products.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "keep_latest_three" {
  provider = aws.catalog_account
  bucket   = aws_s3_bucket.service_catalog_products.id

  rule {
    id     = "LimitObjectVersions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days           = 60
      newer_noncurrent_versions = 3
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Read and decode the first three lines of each YAML file in the afc_cfn_templates directory
data "local_file" "afc_cfn_template_files" {
  for_each = fileset("${path.module}/afc_cfn_templates", "*.yaml")

  filename = "${path.module}/afc_cfn_templates/${each.key}"
}

locals {
  # Extract and decode only the first five lines of each YAML file. This is to avoid the "!Ref" error when decoding AWS CloudFormation.
  afn_templates = {
    for k, v in data.local_file.afc_cfn_template_files : k => yamldecode(join("\n", slice(split("\n", v.content), 0, 5)))
  }
}

# Upload each AFC CloudFormation template file to S3. These templates are meant for AFC usage with account factory.
resource "aws_s3_object" "afc_cfn_templates" {
  provider = aws.catalog_account
  for_each = fileset("${path.module}/afc_cfn_templates", "*.yaml")

  bucket = aws_s3_bucket.service_catalog_products.bucket
  key    = "cfn-templates/${each.key}"
  source = "${path.module}/afc_cfn_templates/${each.key}"

  source_hash = filebase64sha256("${path.module}/afc_cfn_templates/${each.key}")
}

# Create the Service Catalog Portfolio
resource "aws_servicecatalog_portfolio" "afc_portfolio" {
  provider      = aws.catalog_account
  name          = "AFC Products"
  description   = "This portfolio contains products that are meant to be used with Control Tower Account Factory Customization (AFC)."
  provider_name = "Novare Technologies Inc."
}

# Create a product for each CloudFormation template
resource "aws_servicecatalog_product" "afc_products" {
  provider    = aws.catalog_account
  for_each    = aws_s3_object.afc_cfn_templates
  name        = regex("^(.+)\\..+$", each.key)[0] # Extract the filename without the extension
  owner       = "Novare Technologies Inc."
  description = lookup(local.afn_templates[each.key], "Description", "")
  type        = "CLOUD_FORMATION_TEMPLATE"
  provisioning_artifact_parameters {
    name                        = lookup(local.afn_templates[each.key]["Metadata"], "Version", "")
    description                 = "version ${lookup(local.afn_templates[each.key]["Metadata"], "Version", "")}"
    type                        = "CLOUD_FORMATION_TEMPLATE"
    template_url                = "https://${aws_s3_bucket.service_catalog_products.bucket}.s3.${data.aws_region.current.name}.amazonaws.com/cfn-templates/${each.key}"
    disable_template_validation = false
  }
}

# Read and decode the first three lines of each YAML file in the afc_cfn_templates directory
data "local_file" "util_cfn_template_files" {
  for_each = fileset("${path.module}/util_cfn_templates", "*.yaml")

  filename = "${path.module}/util_cfn_templates/${each.key}"
}

locals {
  # Extract and decode only the first five lines of each YAML file. This is to avoid the "!Ref" error when decoding AWS CloudFormation.
  util_templates = {
    for k, v in data.local_file.util_cfn_template_files : k => yamldecode(join("\n", slice(split("\n", v.content), 0, 5)))
  }
}

# Upload each CloudFormation template file to S3. These templates are utility products that are shared across the whole organization.
resource "aws_s3_object" "utlil_cfn_templates" {
  provider = aws.catalog_account
  for_each = fileset("${path.module}/util_cfn_templates", "*.yaml")

  bucket = aws_s3_bucket.service_catalog_products.bucket
  key    = "cfn-templates/${each.key}"
  source = "${path.module}/util_cfn_templates/${each.key}"
}

# Create the Service Catalog Portfolio
resource "aws_servicecatalog_portfolio" "utility_portfolio" {
  provider      = aws.catalog_account
  name          = "Common AWS Utility Products"
  description   = "This portfolio contains products that can help administer one or more AWS accounts."
  provider_name = "Novare Technologies Inc."
}

# Create a product for each CloudFormation template
resource "aws_servicecatalog_product" "utility_products" {
  provider    = aws.catalog_account
  for_each    = aws_s3_object.utlil_cfn_templates
  name        = regex("^(.+)\\..+$", each.key)[0] # Extract the filename without the extension
  owner       = "Novare Technologies Inc."
  description = lookup(local.util_templates[each.key], "Description", "")
  type        = "CLOUD_FORMATION_TEMPLATE"
  provisioning_artifact_parameters {
    name                        = lookup(local.util_templates[each.key]["Metadata"], "Version", "")
    description                 = "version ${lookup(local.util_templates[each.key]["Metadata"], "Version", "")}"
    type                        = "CLOUD_FORMATION_TEMPLATE"
    template_url                = "https://${aws_s3_bucket.service_catalog_products.bucket}.s3.${data.aws_region.current.name}.amazonaws.com/cfn-templates/${each.key}"
    disable_template_validation = false
  }
}

resource "aws_servicecatalog_portfolio_share" "utility_portfolio_share" {
  provider     = aws.catalog_account
  principal_id = data.aws_organizations_organizational_unit.workloads_ou.arn
  portfolio_id = aws_servicecatalog_portfolio.utility_portfolio.id
  # type = "ORGANIZATION"
  type = "ORGANIZATIONAL_UNIT"
}

# Share the AFC Portfolio with the management account
resource "aws_servicecatalog_portfolio_share" "afc_portfolio_share" {
  provider     = aws.catalog_account
  principal_id = data.aws_caller_identity.current.account_id
  portfolio_id = aws_servicecatalog_portfolio.afc_portfolio.id
  # type = "ORGANIZATION"
  type = "ACCOUNT"
}

# # Associate IAM roles, users, or groups with the portfolio (optional)
# resource "aws_servicecatalog_principal_portfolio_association" "example_association" {
#   portfolio_id = aws_servicecatalog_portfolio.example.id
#   principal_arn = "arn:aws:iam::123456789012:role/ExampleRole"
# }

resource "aws_servicecatalog_product_portfolio_association" "afc_product_association" {
  provider     = aws.catalog_account
  for_each     = aws_servicecatalog_product.afc_products
  portfolio_id = aws_servicecatalog_portfolio.afc_portfolio.id
  product_id   = each.value.id
}

resource "aws_servicecatalog_product_portfolio_association" "util_product_association" {
  provider     = aws.catalog_account
  for_each     = aws_servicecatalog_product.utility_products
  portfolio_id = aws_servicecatalog_portfolio.utility_portfolio.id
  product_id   = each.value.id
}


# output "role_arn" {
#   description = "The ARN of the created IAM role"
#   value       = aws_iam_role.aws_control_tower_blueprint_access_role.arn
# }