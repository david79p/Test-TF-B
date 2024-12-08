variable "iam_path" {
  description = "The IAM path"
  default     = "/"
}

variable "function_description" {
  description = "The description of the Lambda function"
  default     = "This function detaches and deletes all igws in this region"
}

variable "function_timeout" {
  description = "The execution timeout of the Lambda function"
  default     = "120"
}

variable "optional_tags" {
  type        = "map"
  description = "Add Optional Tags"
  default     = {}
}

variable "sns_topic_arn" {
  description = "Provide the SNS topic ARN, all config rules notifications will be sent to this topic."
  default     = ""
}

variable "config_recorder_name" {
  description = "The config recorder name. The module will validate that the config recorder is activated before running the config rule"
}
