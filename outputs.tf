output "log_account_id" {
  value = aws_organizations_account.logging_account.id
}

output "security_account_id" {
  value = aws_organizations_account.security_account.id
}

output "catalog_account_id" {
  value = aws_organizations_account.catalog_account.id
}