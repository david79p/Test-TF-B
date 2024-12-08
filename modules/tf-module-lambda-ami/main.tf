data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_target" "start_event" {
  arn  = "${aws_lambda_function.create_ami.arn}"
  rule = "${aws_cloudwatch_event_rule.start_event.name}"
}

resource "aws_cloudwatch_event_target" "stop_event" {
  arn  = "${aws_lambda_function.delete_ami.arn}"
  rule = "${aws_cloudwatch_event_rule.stop_event.name}"
}

resource "aws_cloudwatch_event_rule" "start_event" {
  name                = "start-ami-creation-event"
  description         = "This event will trigger the ami creation procedure"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_rule" "stop_event" {
  name                = "start-ami-deletion-event"
  description         = "This event will trigger the ami deletion procedure"
  schedule_expression = "rate(1 hour)"
}

data "archive_file" "create-ami-archive" {
  type        = "zip"
  source_file = "${path.module}/files/create_ami.py"
  output_path = "${path.module}/files/create_ami.zip"
}

data "archive_file" "delete-ami-archive" {
  type        = "zip"
  source_file = "${path.module}/files/delete_ami.py"
  output_path = "${path.module}/files/delete_ami.zip"
}

resource "aws_lambda_function" "create_ami" {
  filename         = "${data.archive_file.create-ami-archive.output_path}"
  source_code_hash = "${data.archive_file.create-ami-archive.output_base64sha256}"
  function_name    = "${var.lambda_create_name}"
  handler          = "create_ami.lambda_handler"
  role             = "${aws_iam_role.create.arn}"
  runtime          = "python3.6"
  timeout          = "${var.create_ami_timeout}"
  description      = "Creates an AMI from instances tagged with tag:Backup, value:True. During creation the AMI are tagged with a delete date. By default the AMI are kept for ${var.ami_retention_time} days. Override per instance is possible using tag:Retention, value:noOfDays."

  environment {
    variables = {
      region       = "${var.region}"
      retention    = "${var.ami_retention_time}"
      tagname      = "${var.tag_name}"
      default_time = "${var.cw_start_time}"
    }
  }

  tags = "${merge(map("CreatedBy", "Terraform"),var.tags)}"
}

resource "aws_lambda_function" "delete_ami" {
  filename         = "${data.archive_file.delete-ami-archive.output_path}"
  source_code_hash = "${data.archive_file.delete-ami-archive.output_base64sha256}"
  function_name    = "${var.lambda_delete_name}"
  handler          = "delete_ami.lambda_handler"
  role             = "${aws_iam_role.delete.arn}"
  runtime          = "python3.6"
  timeout          = "${var.delete_ami_timeout}"
  description      = "Deletes AMI which are tagged with DeleteOn and a value less equal today. This is only done if we have at least one backup of any instance taken today."

  environment {
    variables = {
      region    = "${var.region}"
      sns_topic = "${var.sns_topic}"
    }
  }

  tags = "${merge(map("CreatedBy", "Terraform"),var.tags)}"
}

resource "aws_lambda_permission" "create_from_cw" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.create_ami.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.start_event.arn}"
}

resource "aws_lambda_permission" "delete_from_cw" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.delete_ami.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.stop_event.arn}"
}

resource "aws_iam_role" "create" {
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

resource "aws_iam_role" "delete" {
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

resource "aws_iam_policy" "create" {
  path = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateImage",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "delete" {
  path = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:DeregisterImage",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "delete_policy_sns_publish" {
  count = "${var.sns_topic == "" ? 0 : 1}"
  path  = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:publish*"
      ],
      "Resource": "${var.sns_topic}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "custom_create" {
  role       = "${aws_iam_role.create.name}"
  policy_arn = "${aws_iam_policy.create.arn}"
}

resource "aws_iam_role_policy_attachment" "custom_delete" {
  role       = "${aws_iam_role.delete.name}"
  policy_arn = "${aws_iam_policy.delete.arn}"
}

resource "aws_iam_role_policy_attachment" "managed_create" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.create.name}"
}

resource "aws_iam_role_policy_attachment" "managed_delete" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.delete.name}"
}

resource "aws_iam_role_policy_attachment" "attach_delete_policy_sns_publish" {
  count = "${var.sns_topic == "" ? 0 : 1}"

  role       = "${aws_iam_role.delete.name}"
  policy_arn = "${aws_iam_policy.delete_policy_sns_publish.arn}"
}
