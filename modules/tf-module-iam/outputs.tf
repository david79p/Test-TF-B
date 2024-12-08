######
# idp
######

output "idp_arn" {
  value = "${element(concat(aws_iam_saml_provider.this.*.arn, list("")), 0)}"
}

output "idp_valid_until" {
  value = "${element(concat(aws_iam_saml_provider.this.*.valid_until, list("")), 0)}"
}

######
# admin
######

output "admin_role_arn" {
  value = "${element(concat(aws_iam_role.admin.*.arn, list("")), 0)}"
}

######
# devops
######

output "devops_role_arn" {
  value = "${element(concat(aws_iam_role.devops.*.arn, list("")), 0)}"
}

output "devops_policy_arn" {
  value = "${element(concat(aws_iam_policy.devops.*.arn, list("")), 0)}"
}

######
# developer
######

output "developer_role_arn" {
  value = "${element(concat(aws_iam_role.developer.*.arn, list("")), 0)}"
}

output "developer_policy_arn" {
  value = "${element(concat(aws_iam_policy.developer.*.arn, list("")), 0)}"
}

######
# support
######

output "support_role_arn" {
  value = "${element(concat(aws_iam_role.support.*.arn, list("")), 0)}"
}

output "support_policy_arn" {
  value = "${element(concat(aws_iam_policy.support.*.arn, list("")), 0)}"
}

######
# audit
######

output "audit_role_arn" {
  value = "${element(concat(aws_iam_role.audit.*.arn, list("")), 0)}"
}

