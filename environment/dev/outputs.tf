#######################################################################################################################
# Development Environment
#######################################################################################################################

output "dev_vpc_id" {
  value = "${module.dev_vpc.vpc_id}"
}

output "dev_eks_kubeconfig" {
  sensitive = true
  value     = "${module.dev_eks.kubeconfig}"
}

output "dev_eks_config_map_aws_auth" {
  sensitive = true
  value     = "${module.dev_eks.config_map_aws_auth}"
}

output "dev-Leads-ContactCustomer_url" {
  value = "${module.Dev-Leads-ContactCustomer.sqs_queue_id}"
}

output "dev-Leads-ContactCustomer-Pango_url" {
  value = "${module.Dev-Leads-ContactCustomer-Pango.sqs_queue_id}"
}

output "dev-Leads-Abandon_url" {
  value = "${module.Dev-Leads-Abandon.sqs_queue_id}"
}

output "dev-Leads-RedPath_url" {
  value = "${module.Dev-Leads-RedPath.sqs_queue_id}"
}

output "dev-Payments-Pango_url" {
  value = "${module.Dev-Payments-Pango.sqs_queue_id}"
}

output "stage-Leads-ContactCustomer_url" {
  value = "${module.Test-Leads-ContactCustomer.sqs_queue_id}"
}

output "stage-Leads-ContactCustomer-Pango_url" {
  value = "${module.Test-Leads-ContactCustomer-Pango.sqs_queue_id}"
}

output "stage-Leads-Abandon_url" {
  value = "${module.Test-Leads-Abandon.sqs_queue_id}"
}

output "stage-Leads-RedPath_url" {
  value = "${module.Test-Leads-RedPath.sqs_queue_id}"
}

output "stage-Payments-Pango_url" {
  value = "${module.Test-Payments-Pango.sqs_queue_id}"
}
###################
# Sms queue outputs
###################

output "Dev-Sms-Abandon_url" {
  value = "${module.Dev-Sms-Abandon.sqs_queue_id}"
}

output "Stage-Sms-Abandon_url" {
  value = "${module.Stage-Sms-Abandon.sqs_queue_id}"
}

output "Dev-Sms-Future-Insurance-Start-Date_url" {
  value = "${module.Dev-Sms-Future-Insurance-Start-Date.sqs_queue_id}"
}

output "Stage-Sms-Future-Insurance-Start-Date_url" {
  value = "${module.Stage-Sms-Future-Insurance-Start-Date.sqs_queue_id}"
}