output "lambda_arn" {
  value = "${aws_lambda_function.this.arn}"
}

output "topic_arn" {
  value = "${var.topic_subscription_arn}"
}
