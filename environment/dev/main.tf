#######################################################################################################################
# Development Environment
#######################################################################################################################

variable "cluster_name" {
  default = "dev-eks-cluster"
  type    = "string"
}

variable "eks_key_name" {
  default = "eks-node"
  type    = "string"
}

########################################################################################################################
# VPC
########################################################################################################################

module "dev_vpc" {
  source = "../../modules/tf-module-vpc"

  #Network
  name = "dev"
  cidr = "10.161.0.0/16"

  azs = [
    "eu-west-1a",
    "eu-west-1b",
  ]

  #Subnets CIDR's
  private_subnets = [
    "10.161.0.0/24",
    "10.161.1.0/24",
  ]

  public_subnets = [
    "10.161.10.0/24",
    "10.161.11.0/24",
  ]

  database_subnets = [
    "10.161.100.0/24",
    "10.161.101.0/24",
  ]

  # Tags below are required for EKS and Kubernetes to discover and manage networking resources.
  vpc_tags = "${
    map(
     "kubernetes.io/cluster/${var.cluster_name}", "shared"
    )
  }"

  subnet_tags = "${
    map(
     "kubernetes.io/cluster/${var.cluster_name}", "shared"
    )
  }"
}

#############################
# Connection between networks
#############################

resource "aws_vpn_gateway" "dev_vpn_gw" {
  vpc_id = "${module.dev_vpc.vpc_id}"

  tags = {
    Name = "Dev-Atid"
  }
}

resource "aws_vpn_gateway_route_propagation" "private_vgw_routes" {
  count = "${length(module.dev_vpc.private_route_table_ids)}"

  vpn_gateway_id = "${aws_vpn_gateway.dev_vpn_gw.id}"
  route_table_id = "${element(module.dev_vpc.private_route_table_ids, count.index)}"
}

resource "aws_vpn_connection" "dev_vpn" {
  vpn_gateway_id      = "${aws_vpn_gateway.dev_vpn_gw.id}"
  customer_gateway_id = "${data.terraform_remote_state.mgmt_account.customer_gateway_id}"
  type                = "ipsec.1"

  tags {
    Name = "Dev-Atid-Integration"
  }
}

resource "aws_route" "dev_to_mgmt_route" {
  count = "${length(module.dev_vpc.private_route_table_ids)}"

  route_table_id         = "${element(module.dev_vpc.private_route_table_ids, count.index)}"
  destination_cidr_block = "${data.terraform_remote_state.mgmt_account.mgmt_vpc_cidr_block}"
  gateway_id             = "${aws_vpn_gateway.dev_vpn_gw.id}"
}

resource "aws_route" "mgmt_to_dev_route" {
  count = "${length(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids)}"

  route_table_id         = "${element(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids, count.index)}"
  destination_cidr_block = "${module.dev_vpc.vpc_cidr_block}"
  gateway_id             = "${data.terraform_remote_state.mgmt_account.mgmt_vpn_gw}"
}

########################################################################################################################
# EKS Cluster
########################################################################################################################

####################
# EKS Nodes Key-pair
####################
resource "aws_key_pair" "eks_key" {
  key_name   = "${var.eks_key_name}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCmtll15iJiyykNtC1jBDHy0k+qI1qBaKHRiTnKbKcOvSdYL6vFeHY94VvgLYiT84j30wV6DQubMEqBAi4hA9R/OeYJzwxisV55Ovk+c+rFLu0/2nWHxqOG77K5Yd/wUa1pPfmtlN3oMjAUcEAVm6j4L/O6qYoF3n4tX2vbrmChYN28Rsh5NwUFRS6qfuek2AJFpX/XNIJYhbIBfz+9CNxCqWOyVpU6Z+fN4S8D8s3ZG6dzfcaRHd9xZcwbV9g1Toj3ac/kf0D42GYSldb1K5W2ToLG4+FEPqC3ds3iatZ2xbLx3Tx9RCUAOtbACHqX/oMDQSqx/s9cxkiN7XdEsCiJ EKS-KEY"
}

module "dev_eks" {
  source = "../../modules/tf-module-eks-cluster"

  environment     = "dev"
  cluster_name    = "${var.cluster_name}"
  k8s_version     = "1.14"
  region          = "${var.region}"
  instance_type   = "m5.large"
  ssh_key_name    = "${var.eks_key_name}"
  ssh_access_pool = "${data.terraform_remote_state.mgmt_account.vpn_cidr_block}"
  vpc_id          = "${module.dev_vpc.vpc_id}"
  worker_subnets  = "${module.dev_vpc.private_subnets_ids}"
  public_subnets  = "${module.dev_vpc.public_subnets_ids}"
  bastion_role    = "${data.terraform_remote_state.mgmt_account.bastion_role_arn}"
  jenkins_role    = "${data.terraform_remote_state.mgmt_account.jenkins_role_arn}"
}
#small change
########################################################################################################################
# SQS Queues
########################################################################################################################

module "Dev-Leads-ContactCustomer-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Leads-ContactCustomer-Pango"
  maxReceiveCount = 4

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "AccessForPango",
      "Effect": "Allow",
      "Principal": {
         "AWS": "609081136822"
      },
      "Action": "sqs:SendMessage"
    }
  ]
}
POLICY
}

module "Dev-Payments-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Payments-Pango"
  maxReceiveCount = 4

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "AccessForPango",
      "Effect": "Allow",
      "Principal": {
         "AWS": "609081136822"
      },
      "Action": "sqs:SendMessage"
    }
  ]
}
POLICY
}

module "Dev-Leads-ContactCustomer" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Leads-ContactCustomer"
  maxReceiveCount = 4
}

module "Dev-Leads-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Leads-Abandon"
  maxReceiveCount = 4
}

module "Dev-Leads-RedPath" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Leads-RedPath"
  maxReceiveCount = 4
}

module "Test-Leads-ContactCustomer-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Test-Leads-ContactCustomer-Pango"
  maxReceiveCount = 4

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "AccessForPango",
      "Effect": "Allow",
      "Principal": {
         "AWS": "609081136822"
      },
      "Action": "sqs:SendMessage"
    }
  ]
}
POLICY
}

module "Test-Payments-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Test-Payments-Pango"
  maxReceiveCount = 4

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "AccessForPango",
      "Effect": "Allow",
      "Principal": {
         "AWS": "609081136822"
      },
      "Action": "sqs:SendMessage"
    }
  ]
}
POLICY
}

module "Test-Leads-ContactCustomer" {
  source          = "../../modules/tf-module-sqs"
  name            = "Test-Leads-ContactCustomer"
  maxReceiveCount = 4
}

module "Test-Leads-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Test-Leads-Abandon"
  maxReceiveCount = 4
}

module "Test-Leads-RedPath" {
  source          = "../../modules/tf-module-sqs"
  name            = "Test-Leads-RedPath"
  maxReceiveCount = 4
}
############
# Sms queues
############

module "Dev-Sms-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Sms-Abandon"
  maxReceiveCount = 4
}

module "Stage-Sms-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Stage-Sms-Abandon"
  maxReceiveCount = 4
}

module "Dev-Sms-Future-Insurance-Start-Date" {
  source          = "../../modules/tf-module-sqs"
  name            = "Dev-Sms-Future-Insurance-Start-Date"
  maxReceiveCount = 4
}

module "Stage-Sms-Future-Insurance-Start-Date" {
  source          = "../../modules/tf-module-sqs"
  name            = "Stage-Sms-Future-Insurance-Start-Date"
  maxReceiveCount = 4
}

########################################################################################################################
# Lambda Functions
########################################################################################################################

############
# Leads-Send
############

resource "aws_iam_role" "Lambda-Leads-Send" {
  name = "Lambda-Leads-Send"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Send-AWSLambdaSQSQueueExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = "${aws_iam_role.Lambda-Leads-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Lambda-Leads-Send.name}"
}

module "Leads-Send-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Send-Dev"
  handler       = "Leads-Send::Leads_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Dev-Leads-Abandon.sqs_queue_arn},${module.Dev-Leads-ContactCustomer.sqs_queue_arn},${module.Dev-Leads-RedPath.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Leads_Api_Endpoint", "https://api-dev.pango-ins.co.il/api/lambda/SendLeads"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Send-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

module "Leads-Send-Staging" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Send-Staging"
  handler       = "Leads-Send::Leads_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  //Change 1 - Leads-Send-Staging
  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Test-Leads-Abandon.sqs_queue_arn},${module.Test-Leads-ContactCustomer.sqs_queue_arn},${module.Test-Leads-RedPath.sqs_queue_arn}"
    batch_size = 10
  }

  //Change 2 - Leads-Send-Staging
  environment = "${merge(
    map(
      "Log_Level", "1",
      "Leads_Api_Endpoint", "https://api-stage.pango-ins.co.il/api/lambda/SendLeads"
    )
  )}"

  //Change 3 - Leads-Send-Staging
  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Send-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

#############
# Leads-Store
#############

resource "aws_iam_role" "Lambda-Leads-Store" {
  name = "Lambda-Leads-Store"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-AWSLambdaSQSQueueExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = "${aws_iam_role.Lambda-Leads-Store.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Lambda-Leads-Store.name}"
}

resource "aws_iam_policy" "Leads-Queue-Policy-Dev" {
  name        = "Leads-Queue-Policy-Dev"
  description = "Policy for allowing queue RW actions for leads queue on development environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DevSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Dev-Leads-RedPath",
        "arn:aws:sqs:eu-west-1:156460081782:Dev-Leads-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Dev-Leads-ContactCustomer"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-LeadsQueuePolicyDev" {
  policy_arn = "${aws_iam_policy.Leads-Queue-Policy-Dev.arn}"
  role       = "${aws_iam_role.Lambda-Leads-Store.name}"
}

// ADD - policy and policy attachment for RW action on queue for Staging
resource "aws_iam_policy" "Leads-Queue-Policy-Stage" {
  name        = "Leads-Queue-Policy-Stage"
  description = "Policy for allowing queue RW actions for leads queue on staging environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StageSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Test-Leads-RedPath",
        "arn:aws:sqs:eu-west-1:156460081782:Test-Leads-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Test-Leads-ContactCustomer"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-LeadsQueuePolicyStage" {
  policy_arn = "${aws_iam_policy.Leads-Queue-Policy-Stage.arn}"
  role       = "${aws_iam_role.Lambda-Leads-Store.name}"
}

//OLD 
/*
module "Leads-Store-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Dev"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 60

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 hour)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Dev-Leads-Abandon",
      "Application_Api_Get_Abandon_Url", "https://api-dev.pango-ins.co.il/api/test/LeadRequestMock"
    )
  )}"

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}
*/
module "Leads-Store-Abandon-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Abandon-Dev"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Dev-Leads-Abandon",
      "Application_Api_Get_Leads_Records_Url", "https://api-dev.pango-ins.co.il/api/lambda/Abandon",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-Abandon-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Leads-Store-Abandon for staging
module "Leads-Store-Abandon-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Abandon-Stage"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Test-Leads-Abandon",
      "Application_Api_Get_Leads_Records_Url", "https://api-stage.pango-ins.co.il/api/lambda/Abandon",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-Abandon-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

module "Leads-Store-ContactCustomer-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-ContactCustomer-Dev"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Dev-Leads-ContactCustomer",
      "Application_Api_Get_Leads_Records_Url", "https://api-dev.pango-ins.co.il/api/lambda/ContactCustomer",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-ContactCustomer-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Leads-Store-ContactCustomer for staging
module "Leads-Store-ContactCustomer-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-ContactCustomer-Stage"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Test-Leads-ContactCustomer",
      "Application_Api_Get_Leads_Records_Url", "https://api-stage.pango-ins.co.il/api/lambda/ContactCustomer",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-ContactCustomer-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

module "Leads-Store-RedPath-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-RedPath-Dev"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Dev-Leads-RedPath",
      "Application_Api_Get_Leads_Records_Url", "https://api-dev.pango-ins.co.il/api/lambda/RedPath",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-RedPath-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Leads-Store-RedPath for staging
module "Leads-Store-RedPath-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-RedPath-Stage"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Test-Leads-RedPath",
      "Application_Api_Get_Leads_Records_Url", "https://api-stage.pango-ins.co.il/api/lambda/RedPath",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Leads-Store-RedPath-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//OLD
/*
module "Leads-Store-Staging" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Staging"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 60

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 hour)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Test-Leads-Abandon",
      "Application_Api_Get_Abandon_Url", "https://stage.pango-ins.co.il/api/test/LeadRequestMock"
    )
  )}"

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}
*/
######################
# Pango-Leads-Send-Dev
######################

module "Pango-Leads-Send-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Pango-Leads-Send-Dev"
  handler       = "Notification-Send::Notification_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Dev-Leads-ContactCustomer-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Notification_Api_Endpoint", "https://api-dev.pango-ins.co.il/api/lambda/pango/ContactCustomer"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Pango-Leads-Send-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Pango-Leads-Send for staging
module "Pango-Leads-Send-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Pango-Leads-Send-Stage"
  handler       = "Notification-Send::Notification_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Test-Leads-ContactCustomer-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Notification_Api_Endpoint", "https://api-stage.pango-ins.co.il/api/lambda/pango/ContactCustomer"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Pango-Leads-Send-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Leads-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

##############
# Payment-Send
##############

resource "aws_iam_role" "Lambda-Payment-Send" {
  name = "Lambda-Payment-Send"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Lambda-Payment-Send-AWSLambdaSQSQueueExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = "${aws_iam_role.Lambda-Payment-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Payment-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Lambda-Payment-Send.name}"
}

module "Payment-Send-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Payment-Send-Dev"
  handler       = "Payment-Send::Payment_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Dev-Payments-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Payment_Api_Endpoint", "https://api-dev.pango-ins.co.il/api/lambda/Payment"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Payment-Send-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Payment-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Payment-Send for staging
module "Payment-Send-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Payment-Send-Stage"
  handler       = "Payment-Send::Payment_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Test-Payments-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Payment_Api_Endpoint", "https://api-stage.pango-ins.co.il/api/lambda/Payment"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Payment-Send-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Payment-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

###########
# Sms-Send
###########


resource "aws_iam_role" "Lambda-Sms-Send" {
  name = "Lambda-Sms-Send"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Send-AWSLambdaSQSQueueExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = "${aws_iam_role.Lambda-Sms-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Lambda-Sms-Send.name}"
}

module "Sms-Send-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Send-Dev"
  handler       = "Sms-Send::Sms_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Dev-Sms-Abandon.sqs_queue_arn},${module.Dev-Sms-Future-Insurance-Start-Date.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Sms_Api_Endpoint", "https://api-dev.pango-ins.co.il/api/lambda/sendsms"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Sms-Send-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Sms-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

module "Sms-Send-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Send-Stage"
  handler       = "Sms-Send::Sms_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  
  trigger {
    type       = "sqs"
    sqs_arn    = "${module.Stage-Sms-Abandon.sqs_queue_arn},${module.Stage-Sms-Future-Insurance-Start-Date.sqs_queue_arn}"
    batch_size = 10
  }

  
  environment = "${merge(
    map(
      "Log_Level", "1",
      "Sms_Api_Endpoint", "https://api-stage.pango-ins.co.il/api/lambda/sendsms"
    )
  )}"

  
  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Sms-Send-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Sms-Send.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}
###########
# Sms-Store
###########


resource "aws_iam_role" "Lambda-Sms-Store" {
  name = "Lambda-Sms-Store"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-AWSLambdaSQSQueueExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = "${aws_iam_role.Lambda-Sms-Store.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Lambda-Sms-Store.name}"
}

resource "aws_iam_policy" "Sms-Queue-Policy-Dev" {
  name        = "Sms-Queue-Policy-Dev"
  description = "Policy for allowing queue RW actions for Sms queue on development environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DevSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Dev-Sms-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Dev-Sms-Future-Insurance-Start-Date"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-SmsQueuePolicyDev" {
  policy_arn = "${aws_iam_policy.Sms-Queue-Policy-Dev.arn}"
  role       = "${aws_iam_role.Lambda-Sms-Store.name}"
}

// ADD - policy and policy attachment for RW action on queue for Staging
resource "aws_iam_policy" "Sms-Queue-Policy-Stage" {
  name        = "Sms-Queue-Policy-Stage"
  description = "Policy for allowing queue RW actions for Sms queue on staging environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StageSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Stage-Sms-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Stage-Sms-Future-Insurance-Start-Date"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-SmsQueuePolicyStage" {
  policy_arn = "${aws_iam_policy.Sms-Queue-Policy-Stage.arn}"
  role       = "${aws_iam_role.Lambda-Sms-Store.name}"
}


module "Sms-Store-Dev" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Store-Dev"
  handler       = "Sms-Store::Sms_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url_Prefix", "https://sqs.eu-west-1.amazonaws.com/156460081782/Dev-Sms-",
      "Application_Api_Get_Sms_Records_Url", "https://api-dev.pango-ins.co.il/api/lambda/sms/messages",
      "Log_Level", "1",
      "Sms_Type_Property", "SmsGroupType",
      "Sms_StateId_Property", "StateId"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Sms-Store-Dev-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Sms-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}

//ADD Lambda Sms-Store-Abandon for staging
module "Sms-Store-Stage" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Store-Stage"
  handler       = "Sms-Store::Sms_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url_Prefix", "https://sqs.eu-west-1.amazonaws.com/156460081782/Stage-Sms-",
      "Application_Api_Get_Sms_Records_Url", "https://api-stage.pango-ins.co.il/api/lambda/sms/messages",
      "Log_Level", "1",
      "Sms_Type_Property", "SmsGroupType",
      "Sms_StateId_Property", "StateId"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.Sms-Store-Stage-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Lambda-Sms-Store.arn}"

  vpc_config {
    subnet_ids         = ["${module.dev_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.dev_vpc.default_sg_id}"]
  }
}


#############
# Logzio-ship
#############
resource "aws_iam_role" "Logzio-Shiper-Role" {
  name = "Logzio-Shiper-Role"

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

  tags = {
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "Logzio-Shiper-Role_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.Logzio-Shiper-Role.name}"
}

module "Leads-Send-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Send-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Lead-Send-Dev"
}

module "Leads-Store-Abandon-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-Abandon-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Abandon-Dev"
}

module "Leads-Store-ContactCustomer-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-ContactCustomer-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-ContactCustomer-Dev"
}

module "Leads-Store-RedPath-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-RedPath-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-RedPath-Dev"
}

module "Pango-Leads-Send-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Pango-Leads-Send-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Pango-Lead-Send-Dev"
}

module "Payment-Send-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Payment-Send-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Payment-Send-Dev"
}

//Change 4 - Leads-Send-Staging
module "Leads-Send-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Send-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Lead-Send-Stage"
}

//ADD - Leads-Store-Abandon-Dev
module "Leads-Store-Abandon-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-Abandon-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Abandon-Stage"
}

//ADD - Leads-Store-ContactCustomer
module "Leads-Store-ContactCustomer-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-ContactCustomer-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-ContactCustomer-Stage"
}

//ADD - Leads-Store-RedPath
module "Leads-Store-RedPath-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-RedPath-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-RedPath-Stage"
}

//ADD - Pango-Leads-Send
module "Pango-Leads-Send-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Pango-Leads-Send-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Pango-Lead-Send-Stage"
}

//ADD - Payment-Send
module "Payment-Send-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Payment-Send-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Payment-Send-Stage"
}

##################
# Sms Log shippers
##################

module "Sms-Send-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Send-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms-Send-Dev"
}

module "Sms-Send-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Send-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms-Send-Stage"
}

module "Sms-Store-Dev-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Store-Dev-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms-Store-Dev"
}

module "Sms-Store-Stage-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Store-Stage-Logzio-ship"
  iam_role      = "${aws_iam_role.Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms-Store-Stage"
}