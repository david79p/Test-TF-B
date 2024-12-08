variable "file_name" {
  description = "Lambda function filename name"
}

variable "function_name" {
  description = "Lambda function name"
}

variable "handler" {
  description = "Lambda function handler"
}

variable "role" {
  description = "Lambda function role"
}

variable "description" {
  description = "Lambda function description"
  default     = "Managed by Terraform"
}

variable "memory_size" {
  description = "Lambda function memory size"
  default     = 128
}

variable "runtime" {
  description = "Lambda function runtime"
  default     = "dotnetcore2.0"
}

variable "timeout" {
  description = "Lambda function runtime"
  default     = 300
}

variable "publish" {
  description = "Publish lambda function"
  default     = false
}

variable "vpc_config" {
  type = "map"
}

variable "environment" {
  description = "Lambda environment variables"
  type        = "map"
  default     = {}
}

variable "trigger" {
  description = "Trigger configuration for this lambda function"
  type        = "map"
  default     = {}
}

variable "cloudwatch_log_subscription" {
  description = "Cloudwatch log stream configuration"
  type        = "map"
  default     = {}
}

variable "tags" {
  description = "Tags for this lambda function"
  type        = "map"
  default     = {}
}

# See bug fix PR: https://github.com/terraform-providers/terraform-provider-aws/pull/3806
variable "reserved_concurrent_executions" {
  description = "(Optional) The amount of reserved concurrent executions for this lambda function. A value of `0` disables lambda from being triggered and `-1` removes any concurrency limitations. Defaults to Unreserved Concurrency Limits `-1`"
  default     = -1
}

variable "region" {
  description = "AWS region"
}

variable "enable_cloudwatch_log_subscription" {
  default = false
}

variable "cloudwatch_log_retention" {
  default = 90
}

locals {
  _tags = {
    Name      = "${var.function_name}"
    CreatedBy = "Terraform"
  }
}

locals {
  source_code_hash     = "${base64sha256(file(var.file_name))}"
  tags                 = "${merge(var.tags, local._tags)}"
  cloudwatch_log_group = "/aws/lambda/${var.function_name}"
}
