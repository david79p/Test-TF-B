# Terraform AWS module for AWS Lambda

## Introduction
This module creates an AWS lambda and all the related resources.

## Usage
```hcl
module "lambda-foo" {
  source = "../../modules/tf-module-lambda"

  ################################################
  #        LAMBDA FUNCTION CONFIGURATION         #
  file_name = "${path.root}/artifacts/foo.zip"

  function_name = "lambda-foo-${terraform.workspace}"
  handler       = "index.foo"
  memory_size   = 1024

  trigger {
    type    = "sqs"
    sqs_arn = "one_sqs_arn,another_sqs_arn"
  }

  environment = "${merge(
    map(
      "foo", "FOO",
      "bar", "BAR",
      "baz", "BAZ"
    )
  )}"

  # out of band configuration is needed because Terraform treats
  # the cloudwatch_log_subscription block as a computed resource
  # and lookup function doesn't work. Accessing via array style is not possible
  # because the cloudwatch_log_subscription block is an optional block.
  enable_cloudwatch_log_subscription = true

  cloudwatch_log_subscription {
    destination_arn = "${module.lambda-elk-logging.lambda_arn}"
    filter_pattern  = "[timestamp=*Z, request_id=\"*-*\", event]"
  }

  #                                              #
  ################################################

  region = "${var.region}"
  role   = "${aws_iam_role.lambda.arn}"
  vpc_config {
    subnet_ids         = ["${module.main_vpc.private_subnets}"]
    security_group_ids = ["${module.main_vpc.vpc_default_sg}"]
  }
}
```

## Pluggable Triggers

### Intro

This module has pluggable triggers. The triggers can be passed by the trigger block.

Example:

```hcl
  trigger {
    type        = "sqs"
    sqs_arn     = "some_sqs_arn"
    batch_size  = 10
  }
```
All the available triggers can be found in the [triggers folder](./triggers)



### Adding a new trigger

Triggers are regular Terraform modules but only used by the main module. The only mandatory inputs are `enable`, `lambda_function_arn` and `type`.

Below is an example of CloudWatch Schedule trigger

```hcl
variable "enable" {
  default = 0
}

variable "schedule_config" {
  default = {}
  type    = "map"
}

variable "lambda_function_arn" {}

resource "aws_cloudwatch_event_rule" "rule" {
  count               = "${var.enable}"
  name                = "${lookup(var.schedule_config, "name")}"
  description         = "${lookup(var.schedule_config, "description")}"
  schedule_expression = "${lookup(var.schedule_config, "schedule_expression")}"
}

resource "aws_cloudwatch_event_target" "lambda" {
  count = "${var.enable}"
  rule  = "${element(aws_cloudwatch_event_rule.rule.*.name, count.index)}"
  arn   = "${var.lambda_function_arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count         = "${var.enable}"
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${var.lambda_function_arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${element(aws_cloudwatch_event_rule.rule.*.arn, count.index)}"
}
```
