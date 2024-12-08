#####
# shared
#####

variable "region" {
  type        = "string"
  description = "The region in which resources are being deployed"
}

#####
# S3 logs
#####
variable "s3_logs_bucket_name" {
  type        = "string"
  description = "Specify the s3 access logs bucket name"
  default     = "s3-access-logs"
}

variable "s3_log_bucket_acl" {
  type    = "string"
  default = "log-delivery-write"
}

variable "s3_log_bucket_versioning" {
  type    = "string"
  default = "false"
}

#####
# Cloudtrail logs
#####
variable "cloudtrail_bucket_name" {
  type        = "string"
  description = "Specify the cloudtrail logs bucket name"
  default     = "cloudtrail-logs"
}

variable "cloudtrail_bucket_acl" {
  type    = "string"
  default = "log-delivery-write"
}

variable "cloudtrail_bucket_versioning" {
  type    = "string"
  default = "false"
}

#####
# AWS Config logs
#####
variable "aws_config_bucket_name" {
  type        = "string"
  description = "Specify the AWS Config bucket name"
  default     = "aws-config"
}

variable "aws_config_bucket_acl" {
  type    = "string"
  default = "log-delivery-write"
}

variable "aws_config_bucket_versioning" {
  type    = "string"
  default = "true"
}

#####
# ELB logs
#####
variable "elb_logs_bucket_name" {
  type        = "string"
  description = "Specify the s3 access logs bucket name"
  default     = "elb-logs"
}

variable "elb_bucket_acl" {
  type    = "string"
  default = "log-delivery-write"
}

variable "elb_bucket_versioning" {
  type    = "string"
  default = "false"
}

#####
# Cloudfront logs
#####
variable "cloudfront_bucket_name" {
  type        = "string"
  description = "Specify the CloudFront access logs bucket name"
  default     = "cloudfront-logs"
}

variable "cloudfront_bucket_acl" {
  type    = "string"
  default = "log-delivery-write"
}

variable "cloudfront_bucket_versioning" {
  type    = "string"
  default = "false"
}

variable "additional_tags" {
  type        = "map"
  description = "a map of additional tags to add to all resources (which supports tagging)."
  default     = {}
}
