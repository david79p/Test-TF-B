resource "aws_sqs_queue" "this" {
  name                        = "${var.name}"
  visibility_timeout_seconds  = "${var.visibility_timeout_seconds}"
  message_retention_seconds   = "${var.message_retention_seconds}"
  max_message_size            = "${var.max_message_size}"
  delay_seconds               = "${var.delay_seconds}"
  receive_wait_time_seconds   = "${var.receive_wait_time_seconds}"
  policy                      = "${var.policy}"
  redrive_policy              = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.deadletter_queue.arn}\",\"maxReceiveCount\":${var.maxReceiveCount}}"
  fifo_queue                  = "${var.fifo_queue}"
  content_based_deduplication = "${var.content_based_deduplication}"
  tags                        = "${var.tags}"
}

resource "aws_sqs_queue" "deadletter_queue" {
  name                        = "${var.name}-deadletter"
  visibility_timeout_seconds  = "${var.visibility_timeout_seconds}"
  message_retention_seconds   = "${var.message_retention_seconds}"
  max_message_size            = "${var.max_message_size}"
  delay_seconds               = "${var.delay_seconds}"
  receive_wait_time_seconds   = "${var.receive_wait_time_seconds}"
  policy                      = "${var.policy}"
  fifo_queue                  = "${var.fifo_queue}"
  content_based_deduplication = "${var.content_based_deduplication}"
  tags                        = "${var.tags}"
}