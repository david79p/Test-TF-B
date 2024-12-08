#######################################################################################################################
# Variables for Route53 Module
#######################################################################################################################
variable "create_route53_zone" {
  description = "Set to true if you want to create the route53 hosted zone"
  type        = "string"
  default     = "true"
}

variable "description" {
  description = "Description of the DNS Zone"
  default     = ""
  type        = "string"
}

variable "domain_name" {
  description = "DNS domain zone"
  type        = "string"
}

variable "records" {
  type        = "map"
  description = "List of DNS Records to add to the DNS zone"

  default = {
    names  = []
    types  = []
    ttls   = []
    values = []
  }
}

variable "alias" {
  type        = "map"
  description = "List of DNS Aliases to add to the DNS zone"

  default = {
    names    = []
    values   = []
    zones_id = []
  }
}
