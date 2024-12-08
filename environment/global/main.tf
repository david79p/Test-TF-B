module "cloudtrail" {
  source = "../../modules/tf-module-cloudtrail"

  bucket_name = "${module.s3.cloudtrail_bucket_id}"
  iam_path    = "/pango-sochnut/"
}

module "cloudtrail_alarms" {
  source = "../../modules/tf-module-cloudtrail-alarms"

  cloudwatch_log_group_name = "${module.cloudtrail.cw_log_group_name}"

  alarms = [
    {
      // CISBenchmark 3.1
      // Catch unauthorized access events in cloudwatch logs
      alarm_name = "UnauthorizedApiCalls"

      metric_name = "unauthorized_api_calls"
      description = "This metric monitors unauthorized API calles"
      pattern     = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode =\"AccessDenied*\") }"
    },
    {
      // CISBenchmark 3.1
      // Catch AWS console sign-in without MFA
      alarm_name = "ConsoleSigninNoMfa"

      metric_name = "console_signin_no_mfa"
      description = "This metric monitors console signin without MFA"
      pattern     = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") }"
    },
    {
      // CISBenchmark 3.3
      // Catch usage of "root" account
      alarm_name = "RootAccountUsage"

      metric_name = "root_account_usage"
      description = "This metric monitors root account usage"
      pattern     = "{ ($.userIdentity.type = \"Root\") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != \"AwsServiceEvent\") }"
    },
    {
      // CISBenchmark 3.4
      // Catch IAM policy changes
      alarm_name = "IamPolicyChanges"

      metric_name = "iam_policy_changes"
      description = "This metric monitors IAM policy changes"
      pattern     = "{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy)}"
    },
    {
      // CISBenchmark 3.5
      // Catch CloudTrail configuration changes
      alarm_name = "CloudTrailConfigChanges"

      metric_name = "cloudtrail_config_changes"
      description = "This metric monitors cloudtrail configuration changes"
      pattern     = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }"
    },
    {
      // CISBenchmark 3.6
      // Catch Console Authentication Failures
      alarm_name = "ConsoleAuthFailures"

      metric_name = "console_auth_failures"
      description = "This metric monitors Console authentication failures"
      pattern     = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }"
    },
    {
      // CISBenchmark 3.7
      // Catch disabling or scheduling deletion of KMS CMK
      alarm_name = "DisableOrDeleteCmkMetric"

      metric_name = "disable_or_delete_cmk_metric"
      description = "This metric monitors changes in the KMS changes (disable or schedule to delete)"
      pattern     = "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }"
    },
    {
      // CISBenchmark 3.8
      // Catch S3 bucket policy changes
      alarm_name = "S3_BucketPolicyChanges"

      metric_name = "s3_bucket_policy_changes"
      description = "This metric monitors changes S3 bucket policies"
      pattern     = "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }"
    },
    {
      // CISBenchmark 3.9  // Catch AWS Config configuration changes

      alarm_name  = "ConfigConfigurationChanges"
      metric_name = "config_configuration_changes"
      description = "This metric monitors AWS Config configuration changes"
      pattern     = "{($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder))}"
    },
    {
      // CISBenchmark 3.10
      // Catch Security Group Changes
      alarm_name = "SecurityGroupChanges"

      metric_name = "security_group_changes"
      description = "This metric monitors security group changes"
      pattern     = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)}"
    },
    {
      // CISBenchmark 3.11
      // Catch NACL Changes
      alarm_name = "NaclChanges"

      metric_name = "nacl_changes"
      description = "This metric monitors network access control lists changes"
      pattern     = "{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }"
    },
    {
      // CISBenchmark 3.12
      // Catch Network gateways Changes
      alarm_name = "GatewaysChanges"

      metric_name = "gateways_changes"
      description = "This metric monitors network gateways changes (IGW/VGW)"
      pattern     = "{ ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }"
    },
    {
      // CISBenchmark 3.13
      // Catch Route Table Changes
      alarm_name = "RouteTableChanges"

      metric_name = "route_table_changes"
      description = "This metric monitors route tables changes"
      pattern     = "{ ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }"
    },
    {
      // CISBenchmark 3.14
      // Catch VPC Changes
      alarm_name = "VpcChanges"

      metric_name = "vpc_changes"
      description = "This metric monitors VPC changes"
      pattern     = "{ ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink) }"
    },
  ]

  cloudwatch_alarm_actions = ["${element(module.sns.sns_topic_arns,0)}"]
}

module "aws_config" {
  source = "../../modules/tf-module-aws-config"

  bucket_name   = "${module.s3.aws_config_bucket_id}"
  iam_path      = "/pango-sochnut/"
  sns_topic_arn = "${element(module.sns.sns_topic_arns, 0)}"
  max_access_key_age = 200
}

module "iam" {
  source = "../../modules/tf-module-iam"

  iam_path             = "/pango-sochnut/"
  idp_name             = "OneLogin-pango-sochnut"
  create_saml_provider = "true"

  create_admin_policy     = "true"
  create_devops_policy    = "true"
  create_developer_policy = "true"
  create_support_policy   = "true"
  create_audit_policy     = "true"

  metadata_file_location = "${path.module}/files/onelogin.xml"
}

module "lambda_config_remove_igw" {
  source               = "../../modules/tf-module-config-lambda-delete-igws"
  config_recorder_name = "${module.aws_config.recorder_name}"
  iam_path             = "/pango-sochnut/"

  optional_tags = {
    Environment = "Production"
  }
}

module "lambda_config_s3_exposed_buckets" {
  source               = "../../modules/tf-module-config-lambda-s3-exposed-buckets"
  config_recorder_name = "${module.aws_config.recorder_name}"
  iam_path             = "/pango-sochnut/"

  optional_tags = {
    Environment = "Production"
  }
}

module "lambda_config_vpc_flowlogs" {
  source = "../../modules/tf-module-config-lambda-vpc-flowlogs"

  config_recorder_name = "${module.aws_config.recorder_name}"
  iam_path             = "/pango-sochnut/"
  sns_topic            = "${element(module.sns.sns_topic_arns, 0)}"

  optional_tags = {
    Environment = "Production"
  }
}

module "lambda_backup" {
  source = "../../modules/tf-module-lambda-ami"

  ami_retention_time = "30"
  iam_path           = "/pango-sochnut/"
  sns_topic          = "${element(module.sns.sns_topic_arns, 0)}"

  tags = {
    Environment = "Production"
  }
}

#############################################
# Lambda for update Cloudfront Security Group
#############################################

module "lambda_update_security_groups" {
  source = "../../modules/tf-module-lambda-allow-from-cloudfront"

  sg-region = "${var.region}"
  iam_path  = "/pango-sochnut/"

  optional_tags = {
    Environment = "Production"
  }
}

module "s3" {
  source = "../../modules/tf-module-s3"

  region = "${data.aws_region.current.name}"

  additional_tags = {
    Environment = "Global"
  }
}

module "sns" {
  source = "../../modules/tf-module-sns"

  sns_topic_names = ["notifications", "alerts"]
}

module "route53" {
  source = "../../modules/tf-module-route53"

  #Hosted zone
  domain_name = "pango-ins.co.il"
  description = "Hosted Zone for Pango-ins.co.il"

  #Records
  records = {
    names = [
      "www.",
    ]

    types = [
      "CNAME",
    ]

    ttls = [
      "300",
    ]

    values = [
      "pango-ins.co.il",
    ]
  }
}
