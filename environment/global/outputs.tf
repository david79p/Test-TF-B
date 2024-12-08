######
# iam
######

output "admin_role_arn" {
  value = "${module.iam.admin_role_arn}"
}

output "devops_role_arn" {
  value = "${module.iam.devops_role_arn}"
}

output "developer_role_arn" {
  value = "${module.iam.developer_role_arn}"
}

output "support_role_arn" {
  value = "${module.iam.support_role_arn}"
}

output "audit_role_arn" {
  value = "${module.iam.audit_role_arn}"
}

output "idp_arn" {
  value = "${module.iam.idp_arn}"
}

######
# s3
######

output "s3_logs_bucket" {
  value = "${module.s3.s3_bucket_id}"
}

output "aws_config_bucket_id" {
  value = "${module.s3.aws_config_bucket_id}"
}

output "cloudtrail_bucket_id" {
  value = "${module.s3.cloudtrail_bucket_id}"
}

output "elb_bucket_id" {
  value = "${module.s3.elb_bucket_id}"
}

output "cloudfront_bucket_id" {
  value = "${module.s3.cloudfront_bucket_id}"
}

######
# sns
######

output "sns_alert_topic_arns" {
  value = ["${module.sns.sns_topic_arns}"]
}

###########
# route 53
###########

output "route53_name_servers" {
  value = "${module.route53.name_servers}"
}