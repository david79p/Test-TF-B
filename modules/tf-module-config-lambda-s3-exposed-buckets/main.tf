locals {
  tags = "${merge(map("CreatedBy", "Terraform"),var.optional_tags)}"
}

data "archive_file" "s3_exposed_bucket_archive" {
  type                    = "zip"
  source_content          = "${file("${path.module}/files/s3-exposed-bucket.py")}"
  source_content_filename = "s3-exposed-bucket.py"
  output_path             = "${path.module}/files/s3-exposed-bucket.zip"
}

resource "aws_lambda_function" "this" {
  filename         = "${data.archive_file.s3_exposed_bucket_archive.output_path}"
  source_code_hash = "${data.archive_file.s3_exposed_bucket_archive.output_base64sha256}"
  function_name    = "aws-config-lambda-s3-exposed-bucket"
  handler          = "s3-exposed-bucket.lambda_handler"
  role             = "${aws_iam_role.this.arn}"
  runtime          = "python2.7"
  timeout          = "300"
  description      = "Ensure that no S3 bucket allow public access."

  tags = "${local.tags}"
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromAWSConfig"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.function_name}"
  principal     = "config.amazonaws.com"
}

resource "aws_iam_role" "this" {
  path = "${var.iam_path}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
}
  EOF
}

resource "aws_iam_role_policy_attachment" "managed" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.this.name}"
}

resource "aws_config_config_rule" "s3_exposed_bucket" {
  name = "${var.config_recorder_name}_s3_exposed_bucket"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = "${aws_lambda_function.this.arn}"

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }

  input_parameters = "{\"Validate\": \"True\"}"
}
