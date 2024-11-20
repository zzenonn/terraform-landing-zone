# You will need to assign users to these groups from the console
# You can do it in terraform, but that's a little too much
resource "aws_identitystore_group" "catalog_admins" {
  display_name      = "CatalogAdmins"
  description       = "These users will be administrators of the catalog account."
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

resource "aws_ssoadmin_account_assignment" "catalog_admins" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  permission_set_arn = data.aws_ssoadmin_permission_set.admin.arn

  principal_id   = aws_identitystore_group.catalog_admins.group_id
  principal_type = "GROUP"

  target_id   = aws_organizations_account.catalog_account.id
  target_type = "AWS_ACCOUNT"
}

# workload admins
resource "aws_identitystore_group" "workload_admins" {
  display_name      = "WorkloadAdmins"
  description       = "These users will be administrators of the workload accounts."
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

# Control tower admins

resource "aws_iam_policy" "control_tower_end_user" {
  name        = "ControlTowerEndUserPolicy"
  description = "Policy for assuming blueprint access role, full access to IAM Identity Center, and Control Tower account creation"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = "${aws_iam_role.aws_control_tower_blueprint_access_role.arn}"
      },
      {
        Action = [
          "sso:*",
          "sso-directory:*",
          "servicecatalog:*",
          "organizations:*",
          "iam:*",
          "access-analyzer:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sso:AttachCustomerManagedPolicyReferenceToPermissionSet",
          "sso:DeletePermissionsBoundaryFromPermissionSet",
          "sso:CreateAccountAssignment",
          "sso:PutPermissionsBoundaryToPermissionSet",
          "sso:DetachCustomerManagedPolicyReferenceFromPermissionSet",
          "sso:DetachManagedPolicyFromPermissionSet",
          "sso:AttachManagedPolicyToPermissionSet",
          "sso:UpdatePermissionSet"
        ]
        Effect   = "Deny"
        Resource = "arn:aws:sso:::account/${data.aws_caller_identity.current.account_id}"
      },
      {
        Action = [
          # Read actions
          "controltower:List*",
          "controltower:GetAccountInfo",
          "controltower:GetLandingZoneOperation",
          "controltower:DescribeLandingZoneConfiguration",
          "controltower:DescribeSingleSignOn",
          "controltower:GetBaselineOperation",
          "controltower:DescribeAccountFactoryConfig",
          "controltower:GetBaseline",
          "controltower:GetEnabledControl",
          "controltower:GetEnabledBaseline",
          "controltower:GetControlOperation",
          "controltower:DescribeGuardrail",
          "controltower:DescribeManagedOrganizationalUnit",
          "controltower:ListTagsForResource",
          "controltower:GetAvailableUpdates",
          "controltower:ListExternalConfigRuleCompliance",
          "controltower:GetLandingZoneDriftStatus",
          "controltower:GetHomeRegion",
          "controltower:GetGuardrailComplianceStatus",
          "controltower:GetLandingZone",
          "controltower:DescribeRegisterOrganizationalUnitOperation",
          "controltower:DescribeGuardrailForTarget",
          "controltower:GetLandingZoneStatus",
          "controltower:DescribeManagedAccount",
          "controltower:ListDriftDetails",
          "controltower:PerformPreLaunchChecks",
          "controltower:DescribeCoreService",
          # Write actions
          "controltower:CreateManagedAccount",
          "controltower:DeregisterOrganizationalUnit",
          "controltower:RegisterOrganizationalUnit",
          "controltower:EnableGuardrail",
          "controltower:UpdateEnabledBaseline",
          "controltower:EnableControl",
          "controltower:DisableControl",
          "controltower:ResetEnabledBaseline",
          "controltower:ManageOrganizationalUnit",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


resource "aws_ssoadmin_customer_managed_policy_attachment" "landing_zone_admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
# Adds permissions to the AWSAccountFactory Group created by landing zone
  permission_set_arn = data.aws_ssoadmin_permission_set.landing_zone_end_user.arn
  customer_managed_policy_reference {
    name = aws_iam_policy.control_tower_end_user.name
  }
}


# # For now, the configuration below is not possible. The role created by the
# # Permission set cannot be assigned to the portfolio. Without knowing the 
# # ID beforehand.

# resource "aws_ssoadmin_permission_set" "landing_zone_admin" {
#   name         = "LandingZoneAdmin"
#   instance_arn = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
# }

# resource "aws_identitystore_group" "landing_zone_admins" {
#   display_name      = "LandingZoneAdmins"
#   description       = "These users will be administrators of the landing zone account. Permission is limited only to landing zone."
#   identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
# }

# resource "aws_ssoadmin_account_assignment" "landing_zone_admins" {
#   instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
#   permission_set_arn = aws_ssoadmin_permission_set.landing_zone_admin.arn

#   principal_id   = data.aws_identitystore_group.landing_zone_end_user_group.group_id
#   principal_type = "GROUP"

#   target_id   = data.aws_caller_identity.current.account_id
#   target_type = "AWS_ACCOUNT"
# }


# resource "aws_ssoadmin_managed_policy_attachment" "service_catalog_end_user_policy" {
#   instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
#   managed_policy_arn = "arn:aws:iam::aws:policy/AWSServiceCatalogEndUserFullAccess"
#   permission_set_arn = aws_ssoadmin_permission_set.landing_zone_admin.arn
# }

# resource "aws_ssoadmin_account_assignment" "landing_zone_admins" {
#   instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
#   permission_set_arn = aws_ssoadmin_permission_set.landing_zone_admin.arn

#   principal_id   = aws_identitystore_group.landing_zone_admins.group_id
#   principal_type = "GROUP"

#   target_id   = data.aws_caller_identity.current.account_id
#   target_type = "AWS_ACCOUNT"
# }