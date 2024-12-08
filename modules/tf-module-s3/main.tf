data "aws_elb_service_account" "current" {}
data "aws_caller_identity" "current" {}

locals {
  s3_bucket_name    = "${data.aws_caller_identity.current.account_id}-${var.s3_logs_bucket_name}-${var.region}"
  cloudtrail_bucket = "${data.aws_caller_identity.current.account_id}-${var.cloudtrail_bucket_name}-${var.region}"
  aws_config_bucket = "${data.aws_caller_identity.current.account_id}-${var.aws_config_bucket_name}-${var.region}"
  elb_logs_bucket   = "${data.aws_caller_identity.current.account_id}-${var.elb_logs_bucket_name}-${var.region}"
  cloudfront_bucket = "${data.aws_caller_identity.current.account_id}-${var.cloudfront_bucket_name}-${var.region}"
}

######
# S3 logs
######

resource "aws_s3_bucket" "s3_logs" {
  bucket = "${local.s3_bucket_name}"
  acl    = "${var.s3_log_bucket_acl}"

  tags = "${merge(map(
    "Name", "${local.s3_bucket_name}",
    "CreatedBy", "Terraform"
    ),var.additional_tags
    )}"

  versioning = {
    enabled = "${var.s3_log_bucket_versioning}"
  }
}

######
# Cloudtrail logs
######

data "template_file" "cloudtrail_bucket_policy" {
  template = "${file("${path.module}/policies/cloudtrail_s3_bucket_policy.json")}"

  vars {
    bucket_name    = "${local.cloudtrail_bucket}"
    account_number = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${local.cloudtrail_bucket}"
  acl    = "log-delivery-write"
  policy = "${data.template_file.cloudtrail_bucket_policy.rendered}"

  tags = "${merge(map(
    "Name", "${local.cloudtrail_bucket}",
    "CreatedBy", "Terraform"
    ),var.additional_tags
    )}"

  logging {
    target_bucket = "${aws_s3_bucket.s3_logs.id}"
    target_prefix = "cloudtrail/"
  }

  versioning = {
    enabled = "${var.cloudtrail_bucket_versioning}"
  }
}

######
# AWS Config bucket
######

data "template_file" "aws_config_bucket_policy" {
  template = "${file("${path.module}/policies/aws_config_s3_bucket_policy.json")}"

  vars {
    bucket_name    = "${local.aws_config_bucket}"
  }
}

resource "aws_s3_bucket" "aws_config" {
  bucket = "${local.aws_config_bucket}"
  acl    = "${var.aws_config_bucket_acl}"
  policy = "${data.template_file.aws_config_bucket_policy.rendered}"

  tags = "${merge(map(
    "Name", "${local.aws_config_bucket}",
    "CreatedBy", "Terraform"
    ),var.additional_tags
    )}"

  versioning = {
    enabled = "${var.aws_config_bucket_versioning}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.s3_logs.id}"
    target_prefix = "config/"
  }
}

######
# ELB logs
######

data "template_file" "elb_bucket_policy" {
  template = "${file("${path.module}/policies/elb_log_s3_bucket_policy.json")}"

  vars {
    bucket_name    = "${local.elb_logs_bucket}"
    elb_account_arn = "${data.aws_elb_service_account.current.arn}"
  }
}

resource "aws_s3_bucket" "elb" {
  bucket = "${local.elb_logs_bucket}"
  acl    = "${var.elb_bucket_acl}"
  policy = "${data.template_file.elb_bucket_policy.rendered}"

  tags = "${merge(map(
    "Name", "${local.elb_logs_bucket}",
    "CreatedBy", "Terraform"
    ),var.additional_tags
    )}"

  versioning = {
    enabled = "${var.elb_bucket_versioning}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.s3_logs.id}"
    target_prefix = "elb/"
  }
}

######
# Cloudfront logs
######

resource "aws_s3_bucket" "cloudfront" {
  bucket = "${local.cloudfront_bucket}"
  acl    = "${var.cloudfront_bucket_acl}"

  tags = "${merge(map(
    "Name", "${local.cloudfront_bucket}",
    "CreatedBy", "Terraform"
  ),var.additional_tags
  )}"

  versioning = {
    enabled = "${var.cloudfront_bucket_versioning}"
  }

  logging {
    target_bucket = "${aws_s3_bucket.s3_logs.id}"
    target_prefix = "cloudfront/"
  }
}
