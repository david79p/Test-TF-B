#######################################################################################################################
# Production Environment
#######################################################################################################################

variable "cluster_name" {
  default = "prod-eks-cluster"
  type    = "string"
}

variable "eks_key_name" {
  default = "prod-eks-node"
  type    = "string"
}

########################################################################################################################
# VPC
########################################################################################################################
module "prod_vpc" {
  source = "../../modules/tf-module-vpc"

  #Network
  name = "prod"
  cidr = "10.165.0.0/16"

  azs = [
    "eu-west-1a",
    "eu-west-1b",
  ]

  #Subnets CIDR's
  private_subnets = [
    "10.165.0.0/24",
    "10.165.1.0/24",
  ]

  public_subnets = [
    "10.165.10.0/24",
    "10.165.11.0/24",
  ]

  database_subnets = [
    "10.165.100.0/24",
    "10.165.101.0/24",
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

resource "aws_vpn_gateway" "prod_vpn_gw" {
  vpc_id = "${module.prod_vpc.vpc_id}"

  tags = {
    Name = "Prod-Atid"
  }
}

resource "aws_vpn_gateway_route_propagation" "private_vgw_routes" {
  count = "${length(module.prod_vpc.private_route_table_ids)}"

  vpn_gateway_id = "${aws_vpn_gateway.prod_vpn_gw.id}"
  route_table_id = "${element(module.prod_vpc.private_route_table_ids, count.index)}"
}

resource "aws_vpn_connection" "prod_vpn" {
  vpn_gateway_id      = "${aws_vpn_gateway.prod_vpn_gw.id}"
  customer_gateway_id = "${data.terraform_remote_state.mgmt_account.customer_gateway_id}"
  type                = "ipsec.1"

  tags {
    Name = "Prod-Atid-Integration"
  }
}

resource "aws_route" "prod_to_mgmt_route" {
  count = "${length(module.prod_vpc.private_route_table_ids)}"

  route_table_id         = "${element(module.prod_vpc.private_route_table_ids, count.index)}"
  destination_cidr_block = "${data.terraform_remote_state.mgmt_account.mgmt_vpc_cidr_block}"
  gateway_id             = "${aws_vpn_gateway.prod_vpn_gw.id}"
}

resource "aws_route" "mgmt_to_prod_route" {
  count = "${length(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids)}"

  route_table_id         = "${element(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids, count.index)}"
  destination_cidr_block = "${module.prod_vpc.vpc_cidr_block}"
  gateway_id             = "${data.terraform_remote_state.mgmt_account.mgmt_vpn_gw}"
}

########################################################################################################################
# EKS Cluster
########################################################################################################################

resource "aws_security_group" "cloudfront-80" {
  name        = "cloudfront-80"
  description = "Security groups which allows access only from Cloudfront IP ranges on port 80"
  vpc_id      = "${module.prod_vpc.vpc_id}"

  tags = {
    Name       = "cloudfront"
    AutoUpdate = "true"
    Protocol   = "http"
  }
}

resource "aws_security_group" "cloudfront-443" {
  name        = "cloudfront-443"
  description = "Security groups which allows access only from Cloudfront IP ranges on port 443"
  vpc_id      = "${module.prod_vpc.vpc_id}"

  tags = {
    Name       = "cloudfront"
    AutoUpdate = "true"
    Protocol   = "https"
  }
}

####################
# EKS Nodes Key-pair
####################
resource "aws_key_pair" "eks_key" {
  key_name   = "${var.eks_key_name}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCUqMXy+XGZkFPtwUOevsNGub0y/4X0OXnDAQM1hrOCiEkTzr93uKgjMCwanA3cw8uo9nVWECKfiLHmyWvhFklrrdB3xcdjW2okWPJnWsarw7e4HKpIPsrZRCnLePUmWtL+QEC7QjGYIEHB+xZ1LTrs9uXXi1Bp5AzhBkbLGFi0WPX0Xfio328qSkwwOkPxIRXiuHq/FiGGdnHWf/2/QLGQftz6wAfEJftEzNO0x1gs3hXNRJUf6ARL/SblviQ/zlkxL1/qziRjBq6q0LbWct1K1yZbLPeMcM+Aq0TBAR6Pi7fUEoPQtpSjCsS9SlQX2TTJTGqwOZbvcbkuGWex4zaR PROD-EKS-KEY"
}

module "prod_eks" {
  source = "../../modules/tf-module-eks-cluster"

  environment     = "prod"
  cluster_name    = "${var.cluster_name}"
  k8s_version     = "1.14"
  region          = "${var.region}"
  instance_type   = "m5.xlarge"
  ssh_key_name    = "${var.eks_key_name}"
  ssh_access_pool = "${data.terraform_remote_state.mgmt_account.vpn_cidr_block}"
  vpc_id          = "${module.prod_vpc.vpc_id}"
  worker_subnets  = "${module.prod_vpc.private_subnets_ids}"
  public_subnets  = "${module.prod_vpc.public_subnets_ids}"
  bastion_role    = "${data.terraform_remote_state.mgmt_account.bastion_role_arn}"
  jenkins_role    = "${data.terraform_remote_state.mgmt_account.jenkins_role_arn}"

  optional_tags = [
    {
      key                 = "Monitored"
      value               = "true"
      propagate_at_launch = true
    },
  ]
}

########################################################################################################################
# SQS Queues
########################################################################################################################

module "Prod-Leads-ContactCustomer-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Leads-ContactCustomer-Pango"
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

module "Prod-Payments-Pango" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Payments-Pango"
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

module "Prod-Leads-ContactCustomer" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Leads-ContactCustomer"
  maxReceiveCount = 4
}

module "Prod-Leads-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Leads-Abandon"
  maxReceiveCount = 4
}

module "Prod-Leads-RedPath" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Leads-RedPath"
  maxReceiveCount = 4
}

module "Prod-Sms-Abandon" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Sms-Abandon"
  maxReceiveCount = 4
}

module "Prod-Sms-Future-Insurance-Start-Date" {
  source          = "../../modules/tf-module-sqs"
  name            = "Prod-Sms-Future-Insurance-Start-Date"
  maxReceiveCount = 4
}

########################################################################################################################
# Lambda Functions
########################################################################################################################

############
# Leads-Send
############

resource "aws_iam_role" "Prod-Lambda-Leads-Send" {
  name = "Prod-Lambda-Leads-Send"

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
  role       = "${aws_iam_role.Prod-Lambda-Leads-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Prod-Lambda-Leads-Send.name}"
}

module "Leads-Send-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Send-Production"
  handler       = "Leads-Send::Leads_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger = {
    type       = "sqs"
    sqs_arn    = "${module.Prod-Leads-Abandon.sqs_queue_arn},${module.Prod-Leads-ContactCustomer.sqs_queue_arn},${module.Prod-Leads-RedPath.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Leads_Api_Endpoint", "https://api.pango-ins.co.il/api/lambda/SendLeads"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Leads-Send-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Send.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

#############
# Leads-Store
#############

resource "aws_iam_role" "Prod-Lambda-Leads-Store" {
  name = "Prod-Lambda-Leads-Store"

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
  role       = "${aws_iam_role.Prod-Lambda-Leads-Store.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Prod-Lambda-Leads-Store.name}"
}

resource "aws_iam_policy" "Leads-Queue-Policy-Prod" {
  name        = "Leads-Queue-Policy-Prod"
  description = "Policy for allowing queue RW actions for leads queue on production environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProductionSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Prod-Leads-RedPath",
        "arn:aws:sqs:eu-west-1:156460081782:Prod-Leads-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Prod-Leads-ContactCustomer"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Leads-Store-LeadsQueuePolicyProd" {
  policy_arn = "${aws_iam_policy.Leads-Queue-Policy-Prod.arn}"
  role       = "${aws_iam_role.Prod-Lambda-Leads-Store.name}"
}

module "Leads-Store-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Production"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 60
  runtime       = "dotnetcore2.1"

  trigger = {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 hour)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Prod-Leads-Abandon",
      "Application_Api_Get_Abandon_Url", "https://api.pango-ins.co.il/api/test/LeadRequestMock"
    )
  )}"

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Store.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

module "Leads-Store-Abandon-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-Abandon-Production"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger = {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Prod-Leads-Abandon",
      "Application_Api_Get_Leads_Records_Url", "https://api.pango-ins.co.il/api/lambda/Abandon",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Leads-Store-Abandon-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Store.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

module "Leads-Store-ContactCustomer-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-ContactCustomer-Production"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger = {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Prod-Leads-ContactCustomer",
      "Application_Api_Get_Leads_Records_Url", "https://api.pango-ins.co.il/api/lambda/ContactCustomer",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Leads-Store-ContactCustomer-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Store.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

module "Leads-Store-RedPath-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Leads-Store-RedPath-Production"
  handler       = "Leads-Store::Leads_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger = {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 minute)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url", "https://sqs.eu-west-1.amazonaws.com/156460081782/Prod-Leads-RedPath",
      "Application_Api_Get_Leads_Records_Url", "https://api.pango-ins.co.il/api/lambda/RedPath",
      "Log_Level", "1"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Leads-Store-RedPath-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Store.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

#############################
# Pango-Leads-Send-Production
#############################

module "Pango-Leads-Send-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Pango-Leads-Send-Production"
  handler       = "Notification-Send::Notification_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger = {
    type       = "sqs"
    sqs_arn    = "${module.Prod-Leads-ContactCustomer-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Notification_Api_Endpoint", "https://api.pango-ins.co.il/api/lambda/pango/ContactCustomer"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Pango-Leads-Send-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Leads-Send.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

##############
# Payment-Send
##############

resource "aws_iam_role" "Prod-Lambda-Payment-Send" {
  name = "Prod-Lambda-Payment-Send"

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
  role       = "${aws_iam_role.Prod-Lambda-Payment-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Payment-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Prod-Lambda-Payment-Send.name}"
}

module "Payment-Send-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Payment-Send-Production"
  handler       = "Payment-Send::Payment_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 15
  runtime       = "dotnetcore2.1"

  trigger = {
    type       = "sqs"
    sqs_arn    = "${module.Prod-Payments-Pango.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "1",
      "Payment_Api_Endpoint", "https://api.pango-ins.co.il/api/lambda/Payment"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Payment-Send-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Payment-Send.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}


##########
# Sms-Send
##########


resource "aws_iam_role" "Prod-Lambda-Sms-Send" {
  name = "Prod-Lambda-Sms-Send"

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
  role       = "${aws_iam_role.Prod-Lambda-Sms-Send.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Send-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Prod-Lambda-Sms-Send.name}"
}

module "Sms-Send-Production" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Send-Production"
  handler       = "Sms-Send::Sms_Send.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 30
  runtime       = "dotnetcore2.1"

  trigger = {
    type       = "sqs"
    sqs_arn    = "${module.Prod-Sms-Abandon.sqs_queue_arn},${module.Prod-Sms-Future-Insurance-Start-Date.sqs_queue_arn}"
    batch_size = 10
  }

  environment = "${merge(
    map(
      "Log_Level", "2",
      "Sms_Api_Endpoint", "https://api.pango-ins.co.il/api/lambda/sendsms"
    )
  )}"

  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Sms-Send-Prod-Logzio-ship.arn}"
  }

  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Sms-Send.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}

###########
# Sms-Store
###########


resource "aws_iam_role" "Prod-Lambda-Sms-Store" {
  name = "Prod-Lambda-Sms-Store"

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
  role       = "${aws_iam_role.Prod-Lambda-Sms-Store.name}"
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "${aws_iam_role.Prod-Lambda-Sms-Store.name}"
}

resource "aws_iam_policy" "Sms-Queue-Policy-Prod" {
  name        = "Sms-Queue-Policy-Prod"
  description = "Policy for allowing queue RW actions for Sms queue on production environment"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProductionSQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessageBatch",
        "sqs:ChangeMessageVisibilityBatch"
      ],
      "Resource": [
        "arn:aws:sqs:eu-west-1:156460081782:Prod-Sms-Abandon",
        "arn:aws:sqs:eu-west-1:156460081782:Prod-Sms-Future-Insurance-Start-Date"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "Lambda-Sms-Store-SmsQueuePolicyProd" {
  policy_arn = "${aws_iam_policy.Sms-Queue-Policy-Prod.arn}"
  role       = "${aws_iam_role.Prod-Lambda-Sms-Store.name}"
}

module "Sms-Store-Prod" {
  source = "../../modules/tf-module-lambda"

  file_name     = "../../files/dummy_lambda_code.zip"
  function_name = "Sms-Store-Production"
  handler       = "Sms-Store::Sms_Store.Function::FunctionHandler"
  memory_size   = 512
  timeout       = 60
  runtime       = "dotnetcore2.1"

  trigger = {
    type                = "cloudwatch-event-schedule"
    schedule_expression = "rate(1 hour)"
  }

  environment = "${merge(
    map(
      "AWS_Service_Url_Prefix", "https://sqs.eu-west-1.amazonaws.com/156460081782/Prod-Sms-",
      "Application_Api_Get_Sms_Records_Url", "https://api.pango-ins.co.il/api/lambda/sms/messages",
      "Log_Level", "2",
      "Sms_Type_Property", "SmsGroupType",
      "Sms_StateId_Property", "StateId"
    )
  )}"
  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription = {
    destination_arn = "${module.Sms-Store-Prod-Logzio-ship.arn}"
  }
  region = "${var.region}"
  role   = "${aws_iam_role.Prod-Lambda-Sms-Store.arn}"

  vpc_config = {
    subnet_ids         = ["${module.prod_vpc.private_subnets_ids}"]
    security_group_ids = ["${module.prod_vpc.default_sg_id}"]
  }

  tags = {
    Environment = "Production"
  }
}


#############
# Logzio-ship
#############
resource "aws_iam_role" "Prod-Logzio-Shiper-Role" {
  name = "Prod-Logzio-Shiper-Role"

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
  role       = "${aws_iam_role.Prod-Logzio-Shiper-Role.name}"
}

module "Leads-Send-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Send-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Lead-Send-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Leads-Store-Abandon-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-Abandon-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Abandon-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Leads-Store-ContactCustomer-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-ContactCustomer-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-ContactCustomer-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Leads-Store-RedPath-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Leads-Store-RedPath-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-RedPath-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Pango-Leads-Send-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Pango-Leads-Send-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Pango-Lead-Send-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Payment-Send-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Payment-Send-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Payment-Send-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Sms-Send-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Send-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms-Send-Prod"

  optional_tags = {
    Environment = "Production"
  }
}

module "Sms-Store-Prod-Logzio-ship" {
  source = "../../modules/tf-module-logzio-shipper"

  function_name = "Sms-Store-Prod-Logzio-ship"
  iam_role      = "${aws_iam_role.Prod-Logzio-Shiper-Role.arn}"
  region        = "${var.region}"
  logzio_token  = "ZXDjtDwjITlkvLXGdRkUULQpeGqbJInk"
  log_type      = "Aws-Log-Shiper-Sms--Store-Prod"

  optional_tags = {
    Environment = "Production"
  }
}
