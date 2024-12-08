locals {
  tags = "${merge(map("CreatedBy", "Terraform"),var.optional_tags)}"
}

data "archive_file" "this" {
  type                    = "zip"
  source_content          = "${file("${path.module}/files/lambda_remove_igws.py")}"
  source_content_filename = "lambda_remove_igws.py"
  output_path             = "${path.module}/files/lambda-remove-igws.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "aws_config_remove_igws"
  filename         = "${data.archive_file.this.output_path}"
  source_code_hash = "${data.archive_file.this.output_base64sha256}"
  handler          = "lambda_remove_igws.lambda_handler"
  role             = "${aws_iam_role.this.arn}"
  runtime          = "python2.7"
  timeout          = "${var.function_timeout}"
  description      = "${var.function_description}"

  environment {
    variables {
      SNSTopicARN = "${var.sns_topic_arn}"
    }
  }

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

resource "aws_iam_policy" "custom" {
  path = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DetachInternetGateway",
        "ec2:DescribeRegions",
        "config:PutEvaluations"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "managed_config" {
  role       = "${aws_iam_role.this.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRulesExecutionRole"
}

resource "aws_iam_role_policy_attachment" "managed_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.this.name}"
}

resource "aws_config_config_rule" "igw_rule" {
  name = "${var.config_recorder_name}-igw-present"

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = "${aws_lambda_function.this.arn}"

    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }

  scope {
    compliance_resource_types = ["AWS::EC2::InternetGateway"]
  }
}
