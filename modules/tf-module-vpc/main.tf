/**
#Terraform Module - Generic VPC#

> This module creates all networking components.

# Overview #
* Generic module for deploying a customized VPC.
* It creates all networking components.

# Resources created within the module:

### VPC ###
  * Creates a new VPC.
  * You can edit different parameters when calling up the module.

### Subnet ###
  * Creates subnet resources.
  * You can choose whether to be private or public subnets.

### Routes ###
  * Creates public and private routes.
  * Creates a single RT for public access.
  * Creates as many private RT as the number of AZ deployed.

### Internet-Gateway ###
  * Creates an Internet-Gateway that will be attached to the VPC.
  * It creates a default route to the internet using the public-RT.

### NAT Gateway ###
  * Creates a NAT Gateway in each AZ.
  * It attaches the NAT Gateway to the private RT in each AZ.

### VPC Endpoints ###
  * Creates S3 Endpoints Services.

### VPC Peering Connection###
  * Creates a Peering Connection with another VPC in different regions/accounts.
  * You need to manual input the owner_id and vpc_id of the acceptor.
  * You need to manual accept the peering connection on the acceptor side.

### DHCP Options Set ###
  * Created new DHCP option set for a custom one.

# Prerequisites & Dependencies: #
* **Terraform v1.23 and above**
* **provider.aws v1.35.0 and above**

# How-to #

* How to declare from the state manifest:

```bash
module "<module-name>" {
  source = "../../modules/tf-module-vpc"

# Description of the variables: #

*/

#######################################################################################################################
# VPC Module
#######################################################################################################################

locals {
  max_subnet_length = "${max(length(var.private_subnets))}"
  nat_gateway_count = "${length(var.azs)}"
  vpc_id            = "${aws_vpc.this.id}"
}

######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block                       = "${var.cidr}"
  instance_tenancy                 = "${var.instance_tenancy}"
  enable_dns_hostnames             = "${var.enable_dns_hostnames}"
  enable_dns_support               = "${var.enable_dns_support}"
  assign_generated_ipv6_cidr_block = "${var.assign_generated_ipv6_cidr_block}"

  tags = "${merge(map("Name", format("%s", var.name)), var.vpc_tags, var.tags)}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count = "${length(var.public_subnets) > 0 ? 1 : 0}"

  vpc_id = "${local.vpc_id}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

########################################################################################################################
# Subnets
########################################################################################################################

################
# Public subnet
################
resource "aws_subnet" "public" {
  count = "${length(var.public_subnets) > 0 ? length(var.azs) : 0}"

  vpc_id                  = "${local.vpc_id}"
  cidr_block              = "${var.public_subnets[count.index]}"
  availability_zone       = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"

  tags = "${merge(map("Name", format("%s-public-%s", var.name, element(var.azs, count.index))), var.tags, var.subnet_tags)}"
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count = "${length(var.private_subnets) > 0 ? length(var.private_subnets) : 0}"

  vpc_id            = "${local.vpc_id}"
  cidr_block        = "${var.private_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = "${merge(map("Name", format("%s-private-%s", var.name, element(var.azs, count.index))), var.tags, var.subnet_tags)}"
}

##################
# Database subnet
##################
resource "aws_subnet" "database" {
  count = "${length(var.database_subnets) > 0 ? length(var.database_subnets) : 0}"

  vpc_id            = "${local.vpc_id}"
  cidr_block        = "${var.database_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = "${merge(map("Name", format("%s-db-%s", var.name, element(var.azs, count.index))), var.tags)}"
}

########################################################################################################################
# Route Tables
########################################################################################################################

######################
# Publiс route tables
######################
resource "aws_route_table" "public" {
  count = "${length(var.public_subnets) > 0 ? 1 : 0}"

  vpc_id = "${local.vpc_id}"

  tags = "${merge(map("Name", format("%s-public", var.name)), var.tags)}"
}

######################
# Private route tables
######################
resource "aws_route_table" "private" {
  count = "${local.max_subnet_length > 0 ? local.nat_gateway_count : 0}"

  vpc_id = "${local.vpc_id}"

  tags = "${merge(map("Name", (local.max_subnet_length > 0 ? format("%s-private-%s", var.name, element(var.azs, count.index)) : "${var.name}-private" )), var.tags)}"

  lifecycle {
    ignore_changes = ["propagating_vgws"]
  }
}

########################################################################################################################
# Routes
########################################################################################################################

##############
#Public Routes
##############
resource "aws_route" "public_internet_gateway" {
  count = "${length(var.public_subnets) > 0 ? 1 : 0}"

  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}

###################
#Private NAT Routes
###################
resource "aws_route" "private_nat_gateway" {
  count = "${var.enable_nat_gateway ? local.nat_gateway_count : 0}"

  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"

  timeouts {
    create = "5m"
  }
}

########################################################################################################################
# NAT Gateway
########################################################################################################################
locals {
  nat_gateway_ips = "${aws_eip.nat.*.id}"
}

resource "aws_eip" "nat" {
  count = "${(var.enable_nat_gateway) ? local.nat_gateway_count : 0}"

  vpc = true

  tags = "${merge(map("Name", format("%s-%s", var.name, element(var.azs, (var.enable_nat_gateway ? count.index : 0)))), var.tags)}"
}

resource "aws_nat_gateway" "this" {
  count = "${var.enable_nat_gateway ? local.nat_gateway_count : 0}"

  allocation_id = "${element(local.nat_gateway_ips, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"

  tags = "${merge(map("Name", format("%s-%s", var.name, element(var.azs, (var.enable_nat_gateway ? count.index : 0)))), var.tags)}"

  depends_on = ["aws_internet_gateway.this"]
}

########################################################################################################################
# Route table association
########################################################################################################################
resource "aws_route_table_association" "private" {
  count = "${length(var.private_subnets) > 0 ? length(var.private_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, (var.enable_nat_gateway ? count.index : 0))}"
}

resource "aws_route_table_association" "public" {
  count = "${length(var.public_subnets) > 0 ? length(var.public_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "database" {
  count = "${length(var.database_subnets) > 0 ? length(var.database_subnets) : 0}"

  subnet_id      = "${element(aws_subnet.database.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, (var.enable_nat_gateway ? count.index : 0))}"
}

########################################################################################################################
# VPC Endpoint for S3
########################################################################################################################
data "aws_vpc_endpoint_service" "s3" {
  count = "${var.enable_s3_endpoint ? 1 : 0}"

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  count = "${var.enable_s3_endpoint ? 1 : 0}"

  vpc_id       = "${local.vpc_id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${var.enable_s3_endpoint ? local.nat_gateway_count : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = "${var.enable_s3_endpoint && length(var.public_subnets) > 0 ? 1 : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${aws_route_table.public.id}"
}

########################################################################################################################
# Peering Connection
########################################################################################################################

resource "aws_vpc_peering_connection" "this" {
  count = "${var.enable_peering_connection ? 1 : 0}"

  peer_vpc_id = "${var.peer_vpc_id}"
  vpc_id      = "${aws_vpc.this.id}"
  auto_accept = true

  tags = "${merge(map("Name", format("%s", var.peering_name)), var.tags)}"
}

########################
# Routes for requester #
########################
resource "aws_route" "this_route_tables" {
  count = "${var.enable_peering_connection ? length(var.azs) : 0}"

  route_table_id            = "${element(var.this_route_table_ids, count.index)}"
  destination_cidr_block    = "${var.peer_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.this.id}"
  depends_on                = ["aws_vpc_peering_connection.this"]
}

########################
# Routes for accepter  #
########################
resource "aws_route" "peer_route_tables" {
  count = "${var.enable_peering_connection ? length(var.peer_route_table_ids) : 0}"

  route_table_id            = "${element(var.peer_route_table_ids, count.index)}"
  destination_cidr_block    = "${aws_vpc.this.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.this.id}"
  depends_on                = ["aws_vpc_peering_connection.this"]
}

########################################################################################################################
# DHCP
########################################################################################################################

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = "${var.enable_dhcp_options ? 1 : 0}"

  domain_name          = "${var.dhcp_options_domain_name}"
  domain_name_servers  = ["${var.dhcp_options_domain_name_servers}"]
  ntp_servers          = ["${var.dhcp_options_ntp_servers}"]
  netbios_name_servers = ["${var.dhcp_options_netbios_name_servers}"]
  netbios_node_type    = "${var.dhcp_options_netbios_node_type}"

  tags = "${merge(map("Name", format("%s", var.name)), var.tags)}"
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = "${var.enable_dhcp_options ? 1 : 0}"

  vpc_id          = "${local.vpc_id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"
}

########################################################################################################################
# Security Groups
########################################################################################################################

########################
# Default Security Group
########################
resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.this.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
