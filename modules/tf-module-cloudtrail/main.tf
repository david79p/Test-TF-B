resource "aws_cloudwatch_log_group" "this" {
  name = "AWS_CloudTrail_Logs"
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
          "Service": "cloudtrail.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
}
EOF
}

resource "aws_iam_policy" "this" {
  path = "${var.iam_path}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
    ],
      "Resource": [
        "arn:aws:logs:*:*:*"
    ]
  }
 ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = "${aws_iam_policy.this.arn}"
  role       = "${aws_iam_role.this.name}"
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.trail_name}"
  s3_bucket_name                = "${var.bucket_name}"
  s3_key_prefix                 = "${var.bucket_key_prefix}"
  is_multi_region_trail         = "${var.is_multi_region_trail}"
  include_global_service_events = "${var.include_global_service_events}"
  enable_log_file_validation    = "${var.enable_log_file_validation}"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.this.arn}"
  cloud_watch_logs_role_arn     = "${aws_iam_role.this.arn}"
}
