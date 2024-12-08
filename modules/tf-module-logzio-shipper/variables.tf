### Lambda variables
variable "region" {
  description = "The AWS region the lambda should work on. It's always deployed in the current provider region!"
  default     = ""
}

variable "function_name" {
  description = "The name of the function"
  default     = "Logzio-ship"
}

variable "iam_role" {
  description = "Required. IAM role for Lambda function"
}

variable "memory_size" {
  description = "Memory used by Lambda function"
  default     = 512
}

variable "timeout" {
  description = "Time for Lambda to keep running"
  default     = 60
}

variable "logzio_token" {
  description = "Required. Your Logz.io account token, which can find in your Settings page (https://app.logz.io/#/dashboard/settings/general) in Logz.io."
}

variable "log_type" {
  description = "Required. The log type you'll use with this Lambda. Please note that you should create a new Lambda for each log type you use. This can be a built-in log type (https://docs.logz.io/user-guide/log-shipping/built-in-log-types.html), or your custom log type"
}

variable "log_format" {
  description = "json or text. If json, the lambda function will attempt to parse the message field as JSON and populate the event data with the parsed fields."
  default     = "json"
}

variable "log_compression" {
  description = "If true, the Lambda will send compressed logs. If false, the Lambda will send uncompressed logs."
  default     = "false"
}

variable "log_enrich" {
  description = "Enriche CloudWatch events with custom properties at shipping time. The format is key1=value1;key2=value2"
  default     = ""
}

variable "iam_path" {
  description = "(Optional) The path to the role. See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html for more information."
  default     = "/"
}

# tags
variable "optional_tags" {
  type        = "map"
  description = "Add Optional Tags"
  default     = {}
}
