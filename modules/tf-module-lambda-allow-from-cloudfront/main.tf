locals {
  tags = "${merge(map("CreatedBy", "Terraform"),var.optional_tags)}"
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${var.topic_subscription_arn}"
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/files/update_security_groups.py"
  output_path = "${path.module}/files/update_security_groups.zip"
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

resource "aws_iam_policy" "this" {
  path = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = "${aws_iam_policy.this.arn}"
  role       = "${aws_iam_role.this.name}"
}

resource "aws_lambda_function" "this" {
  filename         = "${data.archive_file.this.output_path}"
  source_code_hash = "${data.archive_file.this.output_base64sha256}"
  description      = "This function updates tagged security groups with AWS public IP ranges by Service"
  function_name    = "${var.lambda_function_name}"
  handler          = "update_security_groups.lambda_handler"
  role             = "${aws_iam_role.this.arn}"
  runtime          = "python2.7"
  timeout          = "30"

  environment {
    variables = {
      region  = "${var.sg-region}"
      sg_name = "${var.sg-name}"
    }
  }

  tags = "${local.tags}"
}
