#####
# S3 logs
#####

output "s3_bucket_id" {
  value = "${aws_s3_bucket.s3_logs.id}"
}

output "s3_bucket_arn" {
  value = "${aws_s3_bucket.s3_logs.arn}"
}

output "s3_bucket_domain" {
  value = "${aws_s3_bucket.s3_logs.bucket_domain_name}"
}

#####
# Cloudtrail logs
#####

output "cloudtrail_bucket_id" {
  value = "${aws_s3_bucket.cloudtrail.id}"
}

output "cloudtrail_bucket_arn" {
  value = "${aws_s3_bucket.cloudtrail.arn}"
}

output "cloudtrail_bucket_domain" {
  value = "${aws_s3_bucket.cloudtrail.bucket_domain_name}"
}

#####
# AWS Config logs
#####

output "aws_config_bucket_id" {
  value = "${aws_s3_bucket.aws_config.id}"
}

output "aws_config_bucket_arn" {
  value = "${aws_s3_bucket.aws_config.arn}"
}

output "aws_config_bucket_domain" {
  value = "${aws_s3_bucket.aws_config.bucket_domain_name}"
}

#####
# ELB logs
#####

output "elb_bucket_id" {
  value = "${aws_s3_bucket.elb.id}"
}

output "elb_bucket_arn" {
  value = "${aws_s3_bucket.elb.arn}"
}

output "elb_bucket_domain" {
  value = "${aws_s3_bucket.elb.bucket_domain_name}"
}

#####
# Cloudfront logs
#####

output "cloudfront_bucket_id" {
  value = "${aws_s3_bucket.cloudfront.id}"
}

output "cloudfront_bucket_arn" {
  value = "${aws_s3_bucket.cloudfront.arn}"
}

output "cloudfront_bucket_domain" {
  value = "${aws_s3_bucket.cloudfront.bucket_domain_name}"
}