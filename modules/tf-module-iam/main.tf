data "aws_caller_identity" "current" {}

######
# alias
######

resource "aws_iam_account_alias" "alias" {
  count         = "${var.account_alias != "" ? 1 : 0}"
  account_alias = "${var.account_alias}"
}

######
# password policy
######

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = "${var.aws_iam_account_password_policy_minimum_password_length}"
  max_password_age               = "${var.aws_iam_account_password_policy_max_password_age}"
  password_reuse_prevention      = "${var.aws_iam_account_password_policy_password_reuse_prevention}"
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
}

######
# idp
######

resource "aws_iam_saml_provider" "this" {
  count                  = "${var.create_saml_provider == "true" ? 1 : 0}"
  name                   = "${var.idp_name}"
  saml_metadata_document = "${file(var.metadata_file_location)}"
}

######
# admin
######

resource "aws_iam_role" "admin" {
  count = "${var.create_admin_policy == "true" ? 1 : 0}"
  name  = "${var.role_names["admin"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_saml_provider.this.arn}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "admin_policy_attachement_to_role" {
  count = "${var.create_admin_policy == "true" ? 1 : 0}"

  role       = "${aws_iam_role.admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

######
# devops
######

data "template_file" "devops_policy_file" {
  count = "${var.create_devops_policy == "true" ? 1 : 0}"

  template = "${file("${path.module}/policies/devops_iam_user_policy.json")}"

  vars {
    account_id = "${data.aws_caller_identity.current.account_id}"
    path       = "${var.iam_path}"
  }
}

resource "aws_iam_policy" "devops" {
  count = "${var.create_devops_policy == "true" ? 1 : 0}"

  name   = "devops_iam_user_policy"
  path   = "${var.iam_path}"
  policy = "${data.template_file.devops_policy_file.rendered}"
}

resource "aws_iam_role" "devops" {
  count = "${var.create_devops_policy == "true" ? 1 : 0}"
  name  = "${var.role_names["devops"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_saml_provider.this.arn}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "devops_policy_attachement_to_role" {
  count = "${var.create_devops_policy == "true" ? 1 : 0}"

  name       = "devops-attachment-to-role"
  roles      = ["${aws_iam_role.devops.name}"]
  policy_arn = "${aws_iam_policy.devops.arn}"
}

######
# developer
######

data "template_file" "developer_policy_file" {
  count = "${var.create_developer_policy == "true" ? 1 : 0}"

  template = "${file("${path.module}/policies/developer_iam_user_policy.json")}"

  vars {
    account_id = "${data.aws_caller_identity.current.account_id}"
    path       = "${var.iam_path}"
  }
}

resource "aws_iam_policy" "developer" {
  count = "${var.create_developer_policy == "true" ? 1 : 0}"

  name   = "developer_iam_user_policy"
  path   = "${var.iam_path}"
  policy = "${data.template_file.developer_policy_file.rendered}"
}

resource "aws_iam_role" "developer" {
  count = "${var.create_developer_policy == "true" ? 1 : 0}"
  name  = "${var.role_names["developer"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_saml_provider.this.arn}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "developer_policy_attachement_to_role" {
  count = "${var.create_developer_policy == "true" ? 1 : 0}"

  name       = "developer-attachment"
  roles      = ["${aws_iam_role.developer.name}"]
  policy_arn = "${aws_iam_policy.developer.arn}"
}

######
# support
######

data "template_file" "support_policy_file" {
  count = "${var.create_support_policy == "true" ? 1 : 0}"

  template = "${file("${path.module}/policies/support_iam_user_policy.json")}"
}

resource "aws_iam_policy" "support" {
  count = "${var.create_support_policy == "true" ? 1 : 0}"

  name   = "support_iam_user_policy"
  path   = "${var.iam_path}"
  policy = "${data.template_file.support_policy_file.rendered}"
}

resource "aws_iam_role" "support" {
  count = "${var.create_support_policy == "true" ? 1 : 0}"
  name  = "${var.role_names["support"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_saml_provider.this.arn}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "support_policy_attachement_to_role" {
  count = "${var.create_support_policy == "true" ? 1 : 0}"

  name       = "support-attachment"
  roles      = ["${aws_iam_role.support.name}"]
  policy_arn = "${aws_iam_policy.support.arn}"
}

# Attach the SupportUser AWS managed policy to the Support Role
resource "aws_iam_policy_attachment" "supportuser_managed_policy_attachement_to_role" {
  count = "${var.create_support_policy == "true" ? 1 : 0}"

  name       = "support-attachment"
  roles      = ["${aws_iam_role.support.name}"]
  policy_arn = "arn:aws:iam::aws:policy/job-function/SupportUser"
}

######
# audit
######

resource "aws_iam_role" "audit" {
  count = "${var.create_audit_policy == "true" ? 1 : 0}"
  name  = "${var.role_names["audit"]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_saml_provider.this.arn}"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "audit_policy_attachement_to_role" {
  count = "${var.create_audit_policy == "true" ? 1 : 0}"

  name       = "audit-attachment-to-role"
  roles      = ["${aws_iam_role.audit.name}"]
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
