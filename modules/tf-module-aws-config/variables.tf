variable "sns_topic_arn" {
  description = "Provide the SNS topic ARN, all config rules notifications will be sent to this topic."
  default     = ""
}

variable "bucket_name" {
  description = "The S3 bucket to send AWS Config events to"
}

variable "iam_path" {
  description = "The service role and policy iam path"
  default     = "/"
}


variable "max_access_key_age" {
  description = "Maximum number of days within which the access keys must be rotated.The default value is 90 days."
  default = 90
}