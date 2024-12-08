
variable "iam_path" {
  description = "The IAM path for the created AWS Lambda role"
  default = "/"
}
variable "config_recorder_name" {
  description = "The config recorder name. The module will validate that the config recorder is activated before running the config rule"
}

variable "optional_tags" {
  type        = "map"
  description = "Add Optional Tags"
  default     = {}
}