locals {
  tags = "${merge(map("CreatedBy", "Terraform"),var.optional_tags)}"
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = "${path.module}/files"
  output_path = "${path.module}/files/Lambda-Logzio-ship.zip"
}

resource "aws_lambda_function" "this" {
  filename         = "${data.archive_file.this.output_path}"
  source_code_hash = "${data.archive_file.this.output_base64sha256}"
  description      = "This function ship cloudwatch logs to Logz.io"
  function_name    = "${var.function_name}"
  handler          = "lambda_function.lambda_handler"
  role             = "${var.iam_role}"
  runtime          = "python2.7"
  memory_size      = "${var.memory_size}"
  timeout          = "${var.timeout}"

  environment {
    variables = {
      FORMAT   = "${var.log_format}"
      URL      = "https://listener.logz.io:8071"
      TOKEN    = "${var.logzio_token}"
      TYPE     = "${var.log_type}"
      COMPRESS = "${var.log_compression}"
      ENRICH   = "${var.log_enrich}"
    }
  }

  tags = "${local.tags}"
}

resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.function_name}"
  principal     = "logs.${var.region}.amazonaws.com"
}
