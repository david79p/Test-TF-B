variable "enable" {
  default = 0
}

variable "lambda_function_arn" {}

variable "sqs_arn" {}

variable "batch_size" {}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  count            = "${var.enable * length(split(",", var.sqs_arn))}"
  batch_size       = "${var.batch_size}"
  event_source_arn = "${element(split(",", var.sqs_arn ), count.index)}"
  enabled          = true
  function_name    = "${var.lambda_function_arn}"
}
