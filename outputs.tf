#######################################################################################################################
# Production Environment
#######################################################################################################################

output "prod_vpc_id" {
  value = "${module.prod_vpc.vpc_id}"
}

output "prod_eks_kubeconfig" {
  sensitive = true
  value     = "${module.prod_eks.kubeconfig}"
}

output "prod_eks_config_map_aws_auth" {
  sensitive = true
  value     = "${module.prod_eks.config_map_aws_auth}"
}

output "prod-Leads-ContactCustomer_url" {
  value = "${module.Prod-Leads-ContactCustomer.sqs_queue_id}"
}

output "prod-Leads-ContactCustomer-Pango_url" {
  value = "${module.Prod-Leads-ContactCustomer-Pango.sqs_queue_id}"
}

output "prod-Leads-Abandon_url" {
  value = "${module.Prod-Leads-Abandon.sqs_queue_id}"
}

output "prod-Leads-RedPath_url" {
  value = "${module.Prod-Leads-RedPath.sqs_queue_id}"
}

output "prod-Payments-Pango_url" {
  value = "${module.Prod-Payments-Pango.sqs_queue_id}"
}
