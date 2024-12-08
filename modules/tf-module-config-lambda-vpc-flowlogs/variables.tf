variable "toggle" {
  description = "Enable or disable the creation of this config rule [on/off]"
  default     = "off"
}

variable "name" {
  description = "The name of the Lambda function"
  default     = "vpc_flow_logs_governance"
}

variable "description" {
  description = "The description of the Lambda function"
  default     = "This function checks whether VPC flow logs are enabled and tries to enable them if required"
}

variable "lambda_timeout" {
  description = "The execution timeout of the Lambda function"
  default     = "60"
}

variable "flow_logs_traffic_type" {
  description = "The type of traffic flow which will be logged. Valid values are: ACCEPT,REJECT,ALL"
  default     = "ALL"
}


variable "config_recorder_name" {
  description = "The Config Recorder name. The module will validate that the Config Recorder is activated before creating the Config Rule"
}

# tags
variable "optional_tags" {
  type        = "map"
  description = "Add Optional Tags"
  default     = {}
}


variable "iam_path" {
  description = "The IAM path for the created AWS Lambda role"
  default = "/"
}

variable "sns_topic" {
  description = "The arn of the sns topic to publish problems to"
  default     = ""
}