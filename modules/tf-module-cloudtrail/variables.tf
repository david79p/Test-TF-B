variable "iam_path" {
  description = "The service role and policy iam path"
  default     = "/"
}

variable "bucket_name" {
  description = "The S3 bucket to send AWS Cloudtrail events to"
}

variable "bucket_key_prefix" {
  description = "Specify a log file prefix for the S3 bucket. The prefix is an addition to the URL for an Amazon S3 object that creates a folder-like organization in your bucket. (without the /)"
  default     = ""
}

variable "trail_name" {
  description = "Specify the cloudtrail name"
  default     = "cloudtrail"
}

variable "is_multi_region_trail" {
  description = "Specifies whether the trail is created in the current region or in all regions. Defaults to true."
  default     = "true"
}

variable "include_global_service_events" {
  description = "Specifies whether the trail is publishing events from global services such as IAM to the log files. Defaults to false. (Not relevant for all regions trail)"
  default     = "true"
}

variable "enable_log_file_validation" {
  description = "Specifies whether log file integrity validation is enabled. Defaults to false."
  default     = "true"
}