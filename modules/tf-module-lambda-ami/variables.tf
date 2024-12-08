### Global Variables

variable "region" {
  description = "The AWS region the lambda should work on. It's always deployed in the current provider region!"
  default     = ""
}

### CloudWatch variables

variable "cw_start_time" {
  description = "The time when the ami creation should occur. Ex: 08"
  default     = "08"
}

variable "cw_stop_time" {
  description = "unused WAS: The time when the ami deletion should occur Ex: 20"
  default     = "20"
}

### AMI Variables
variable "ami_retention_time" {
  description = "The time (in days) the AMI's will be stored"
  default     = "30"
}

### Lambda variables
variable "lambda_create_name" {
  description = "The name of the function which will CREATE the AMIs"
  default     = "Create-ami"
}

variable "tag_name" {
  description = "The tag to update with the value 'Backup'"
  default     = "ApplicationRole"
}

variable "lambda_delete_name" {
  description = "The name of the function which will DELETE the AMIs"
  default     = "Delete-ami"
}

variable "create_ami_timeout" {
  description = "The lambda CREATE timeout"
  default     = "300"
}

variable "delete_ami_timeout" {
  description = "The lambda DELETE timeout"
  default     = "300"
}

variable "sns_topic" {
  description = "The arn of the sns topic to publish problems to"
  default     = ""
}

variable "iam_path" {
  description = "(Optional) The path to the role. See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html for more information."
  default     = "/"
}

variable "tags" {
  description = "Tags for lambda functions"
  type        = "map"
  default     = {}
}
