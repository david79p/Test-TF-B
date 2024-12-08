data "aws_s3_bucket" "config" {
  bucket = "${var.bucket_name}"
}

######
# IAM Resources
######

resource "aws_iam_role" "this" {
  path = "${var.iam_path}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "this" {
  path = "${var.iam_path}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${data.aws_s3_bucket.config.arn}",
        "${data.aws_s3_bucket.config.arn}/*"
      ]
    },
    {
      "Effect":"Allow",
      "Action":"sns:Publish",
      "Resource":"${var.sns_topic_arn}"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "custom" {
  policy_arn = "${aws_iam_policy.this.arn}"
  role       = "${aws_iam_role.this.name}"
}

resource "aws_iam_role_policy_attachment" "managed" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
  role       = "${aws_iam_role.this.name}"
}

######
# AWS Config
######

resource "aws_config_configuration_recorder" "this" {
  role_arn = "${aws_iam_role.this.arn}"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true

    // change to variable when changing to module
  }
}

resource "aws_config_delivery_channel" "this" {
  s3_bucket_name = "${var.bucket_name}"

  depends_on = [
    "aws_config_configuration_recorder.this",
  ]

  sns_topic_arn = "${var.sns_topic_arn}"

  snapshot_delivery_properties {
    delivery_frequency = "One_Hour"
  }
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = "${aws_config_configuration_recorder.this.name}"
  is_enabled = true

  depends_on = [
    "aws_config_delivery_channel.this",
  ]
}

resource "aws_config_config_rule" "ct_enabled" {
  name = "cloudtrail_enabled"

  "source" {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
}

resource "aws_config_config_rule" "required_tags" {
  name = "required_tags"

  "source" {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  scope {
    compliance_resource_types = ["AWS::EC2::Instance","AWS::S3::Bucket"]
  }

  input_parameters = "{\"tag1Key\":\"CreatedBy\"}"
}


resource "aws_config_config_rule" "access-keys-rotated" {
   name = "access-keys-rotated"
   "source" {
     owner = "AWS"
     source_identifier = "ACCESS_KEYS_ROTATED"
   }

   input_parameters = "{\"maxAccessKeyAge\":\"${var.max_access_key_age}\"}"
}