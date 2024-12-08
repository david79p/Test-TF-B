locals {
  tags = "${merge(map("CreatedBy", "Terraform"),var.optional_tags)}"
}

data "archive_file" "this" {
  type                    = "zip"
  source_content          = "${file("${path.module}/files/vpc-flow-logs-enabled.py")}"
  source_content_filename = "vpc-flow-logs-enabled.py"
  output_path             = "${path.module}/files/vpc-flow-logs-enabled.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.name}"
  filename         = "${data.archive_file.this.output_path}"
  source_code_hash = "${data.archive_file.this.output_base64sha256}"
  handler          = "vpc-flow-logs-enabled.lambda_handler"
  role             = "${aws_iam_role.lambda.arn}"
  runtime          = "python2.7"
  timeout          = "${var.lambda_timeout}"
  description      = "${var.description}"

  environment {
    variables = {
      FlowLogsIAMRoleARN  = "${aws_iam_role.flowlogs.arn}"
      FlowLogsTrafficType = "${var.flow_logs_traffic_type}"
      SNSTopicARN         = "${var.sns_topic}"
    }
  }

  tags = "${local.tags}"
}

resource "aws_lambda_permission" "allow_aws_config" {
  statement_id  = "AllowExecutionFromAWSConfig"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.function_name}"
  principal     = "config.amazonaws.com"
}

resource "aws_iam_role" "lambda" {
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

resource "aws_iam_role" "flowlogs" {
  path = "${var.iam_path}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "vpc-flow-logs.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
}
  EOF
}

resource "aws_iam_policy" "lambda" {
  path = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "s3:GetObject",
          "ec2:DescribeVpcs",
          "ec2:DescribeRegions",
          "ec2:CreateFlowLogs",
          "ec2:DescribeFlowLogs",
          "config:Put*",
          "config:Get*",
          "config:List*",
          "config:Describe*",
          "sns:Publish"
      ],
      "Resource": "*"
    },
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

resource "aws_iam_role_policy_attachment" "managed-lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.lambda.name}"
}

resource "aws_iam_role_policy_attachment" "custom-lambda" {
  policy_arn = "${aws_iam_policy.lambda.arn}"
  role       = "${aws_iam_role.lambda.name}"
}

resource "aws_iam_role_policy_attachment" "managed-flowlogs" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = "${aws_iam_role.flowlogs.name}"
}

resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  name = "${var.config_recorder_name}-vpc_flow_logs_enabled"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = "${aws_lambda_function.this.arn}"

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::EC2::VPC"]
  }
}
