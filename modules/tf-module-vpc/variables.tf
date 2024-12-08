#######################################################################################################################
# Variables for Networking Module
#######################################################################################################################

######
# VPC
######
variable "name" {
  description = "Name to be used on all the resources as identifier and the VPC name"
  type        = "string"
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, eg: 192.168.100.0/24"
  type        = "string"
}

variable "azs" {
  description = "A list of availability zones in the region, eg ['eu-west-1a','eu-west-1b']"
  default     = []
  type        = "list"
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  default     = "default"
  type        = "string"
}

variable "assign_generated_ipv6_cidr_block" {
  description = "Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block"
  default     = false
  type        = "string"
}

#########
# Subnets
#########
variable "public_subnets" {
  description = "A list of public subnets inside the VPC, eg: [192.168.100.0/24, 192.168.200.0/24]"
  default     = []
  type        = "list"
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC, eg: [192.168.100.0/24, 192.168.200.0/24]"
  default     = []
  type        = "list"
}

variable "database_subnets" {
  description = "A list of database subnets inside the VPC, eg: [192.168.100.0/24, 192.168.200.0/24]"
  default     = []
  type        = "list"
}

variable "create_database_subnet_group" {
  description = "Controls if database subnet group should be created"
  default     = true
  type        = "string"
}

variable "map_public_ip_on_launch" {
  description = "Should be false if you do not want to auto-assign public IP on launch in the public subnet"
  default     = true
  type        = "string"
}

###############
# NAT Gateways
###############
variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  default     = true
  type        = "string"
}

###################
# Endpoint Services
###################
variable "enable_s3_endpoint" {
  description = "Should be true if you want to provision an S3 endpoint to the VPC"
  default     = true
  type        = "string"
}

#####################
# Peering Connection
#####################
variable "enable_peering_connection" {
  description = "Should be true if you want to create a peering connection to another vpc"
  default     = false
  type        = "string"
}

variable "peer_vpc_id" {
  description = "The ID of the VPC with which you are creating the VPC Peering Connection"
  default     = ""
  type        = "string"
}

variable "peer_cidr_block" {
  type        = "string"
  default     = ""
  description = "The CIDR block of the acceptor's VPC"
}

variable "peer_route_table_ids" {
  type        = "list"
  default     = []
  description = "The route tables id's of the acceptor's VPC"
}

variable "this_route_table_ids" {
  type        = "list"
  default     = []
  description = "The route tables id's of the requester's VPC"
}

variable "peering_name" {
  type        = "string"
  default     = ""
  description = "The name to give to the peering connection"
}

##############
# DHCP support
##############
variable "enable_dhcp_options" {
  description = "Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers, netbios servers, and/or netbios server type"
  default     = false
  type        = "string"
}

variable "dhcp_options_domain_name" {
  description = "Specifies DNS name for DHCP options set"
  default     = ""
  type        = "string"
}

variable "dhcp_options_domain_name_servers" {
  description = "Specify a list of DNS server addresses for DHCP options set, default to AWS provided"
  default     = ["AmazonProvidedDNS"]
  type        = "list"
}

variable "dhcp_options_ntp_servers" {
  description = "Specify a list of NTP servers for DHCP options set"
  default     = []
  type        = "list"
}

variable "dhcp_options_netbios_name_servers" {
  description = "Specify a list of netbios servers for DHCP options set"
  default     = []
  type        = "list"
}

variable "dhcp_options_netbios_node_type" {
  description = "Specify netbios node_type for DHCP options set"
  default     = ""
  type        = "string"
}

#############
# DNS Support
#############
variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  default     = true
  type        = "string"
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  default     = true
  type        = "string"
}

#######
# Tags
#######
variable "tags" {
  description = "A map of tags to add to all resources"
  default     = {}
  type        = "map"
}

variable "subnet_tags" {
  description = "A map of tags to add to subnets"
  default     = {}
  type        = "map"
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  default     = {}
  type        = "map"
}
