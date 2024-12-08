### Lambda variables
variable "lambda_function_name" {
  description = "The name of the function"
  default     = "aws-cloudfront-ip-space-change"
}

variable "sg-region" {
  description = "The AWS region where the tagged security groups exist"
}

variable "sg-name" {
  description = "Name of the security group to consider"
  default     = "cloudfront"
}

variable "iam_path" {
  description = "(Optional) The path to the role. See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html for more information."
  default     = "/"
}

### SNS variables
variable "topic_subscription_arn" {
  description = "The SNS topic ARN for the AWS IP updates"
  default     = "arn:aws:sns:us-east-1:806199016981:AmazonIpSpaceChanged"
}

# tags
variable "optional_tags" {
  type        = "map"
  description = "Add Optional Tags"
  default     = {}
}