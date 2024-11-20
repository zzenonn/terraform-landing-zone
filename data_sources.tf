data "aws_ssoadmin_instances" "identity_center" {
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_ssoadmin_permission_set" "admin" {
  instance_arn = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  name         = "AWSAdministratorAccess"
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_ssoadmin_permission_set" "landing_zone_end_user" {
  instance_arn = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  name         = "AWSServiceCatalogEndUserAccess"
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_identitystore_group" "control_admin_group" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWSControlTowerAdmins"
    }
  }
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_identitystore_group" "landing_zone_end_user_group" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWSAccountFactory"
    }
  }
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_organizations_organization" "org" {
  depends_on = [ aws_controltower_landing_zone.landing_zone ]
}

data "aws_organizations_organizational_unit" "workloads_ou" {
  parent_id  = data.aws_organizations_organization.org.roots[0].id
  name       = var.sandbox_ou_name
  depends_on = [aws_controltower_landing_zone.landing_zone]
}

data "aws_region" "current" {}