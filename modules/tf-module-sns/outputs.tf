output "sns_topic_arns" {
  value = ["${aws_sns_topic.this.*.arn}"]
}
