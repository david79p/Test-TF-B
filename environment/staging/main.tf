#####
# VPC
#####
module "staging_vpc" {
  source = "../../modules/tf-module-vpc"

  #Network
  name = "staging"
  cidr = "10.162.0.0/16"

  azs = [
    "eu-west-1a",
    "eu-west-1b",
  ]

  #Subnets CIDR's
  private_subnets = [
    "10.162.0.0/24",
    "10.162.1.0/24",
  ]

  public_subnets = [
    "10.162.10.0/24",
    "10.162.11.0/24",
  ]

  database_subnets = [
    "10.162.100.0/24",
    "10.162.101.0/24",
  ]
}

#############################
# Connection between networks
#############################

resource "aws_vpn_gateway" "staging_vpn_gw" {
  vpc_id = "${module.staging_vpc.vpc_id}"

  tags = {
    Name = "Stage-Atid"
  }
}

resource "aws_vpn_gateway_route_propagation" "private_vgw_routes" {
  count = "${length(module.staging_vpc.private_route_table_ids)}"

  vpn_gateway_id = "${aws_vpn_gateway.staging_vpn_gw.id}"
  route_table_id = "${element(module.staging_vpc.private_route_table_ids, count.index)}"
}

resource "aws_vpn_connection" "staging_vpn" {
  vpn_gateway_id      = "${aws_vpn_gateway.staging_vpn_gw.id}"
  customer_gateway_id = "${data.terraform_remote_state.mgmt_account.customer_gateway_id}"
  type                = "ipsec.1"

  tags {
    Name = "Stage-Atid-Integration"
  }
}

resource "aws_route" "staging_to_mgmt_route" {
  count = "${length(module.staging_vpc.private_route_table_ids)}"

  route_table_id         = "${element(module.staging_vpc.private_route_table_ids, count.index)}"
  destination_cidr_block = "${data.terraform_remote_state.mgmt_account.mgmt_vpc_cidr_block}"
  gateway_id             = "${aws_vpn_gateway.staging_vpn_gw.id}"
}

resource "aws_route" "mgmt_to_staging_route" {
  count = "${length(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids)}"

  route_table_id         = "${element(data.terraform_remote_state.mgmt_account.mgmt_private_rt_ids, count.index)}"
  destination_cidr_block = "${module.staging_vpc.vpc_cidr_block}"
  gateway_id             = "${data.terraform_remote_state.mgmt_account.mgmt_vpn_gw}"
}
