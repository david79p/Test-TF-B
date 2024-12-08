variable "toggle" {
  default     = "on"
  description = "Whether to activate this module or not"
}

variable "alarms" {
  type = "list"
}

variable "cloudwatch_log_group_name" {
  type = "string"
}

variable "cloudwatch_alarm_actions" {
  type    = "list"
  default = []
}
