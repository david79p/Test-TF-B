/**
#Terraform Module - Route53#

> This module creates an Route53 Hosted Zone.

# Overview #
* Generic module for creating a Route53 Hosted Zone.
* You can add records and aliases to the Zone.

#Resources created within the module:

### Route53 Zone ###
  * Creates a Hosted Zone in Route53.

### Route53 Records ##
  * Creates a map of records in the Routed53 Hosted Zone.

### Route53 Aliases ###
  * Creates a map of aliases records in the Routed53 Hosted Zone.

# Prerequisites & Dependencies: #
* **Terraform v1.23 and above**
* **provider.aws v1.35.0 and above**

# How-to #
* How to declare from the state manifest:

```bash

module "<module-name>" {
  source = "../../modules/tf-module-route53"

  #hosted zone
  create_route53_zone = "true"
  domain_name         = "pango-ins.co.il"
  description         = "Hosted Zone for Pango-ins.co.il"

  #records
  records = {
    names = [
      "www.",
      "admin.",
    ]

    types = [
      "CANME",
      "CNAME",
    ]

    ttls = [
      "3600",
      "3600",
    ]

    values = [
      "mydomain.com",
      "mydomain.com",
    ]
  }

}

```

## Description of the variables: ##
*/
#######################################################################################################################
# Route53 Module
#######################################################################################################################

##############
# Route53 Zone
##############
resource "aws_route53_zone" "this" {
  count = "${var.create_route53_zone == true ? 1 : 0}"

  name    = "${var.domain_name}"
  comment = "${var.description}"
}

################
# Route53 Record
################
resource "aws_route53_record" "this" {
  count = "${var.create_route53_zone == true ? length(var.records["names"]) : 0}"

  zone_id = "${element(aws_route53_zone.this.*.zone_id, 0)}"
  name    = "${element(var.records["names"], count.index)}${var.domain_name}"
  type    = "${element(var.records["types"], count.index)}"
  ttl     = "${element(var.records["ttls"], count.index)}"
  records = ["${split(",", element(var.records["values"], count.index))}"]
}

###############
# Route53 Alias
###############
resource "aws_route53_record" "alias" {
  count = "${var.create_route53_zone == true ? length(var.alias["names"]) : 0}"

  zone_id = "${element(aws_route53_zone.this.*.zone_id, 0)}"
  name    = "${element(var.alias["names"], count.index)}${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${element(var.alias["values"], count.index)}"
    zone_id                = "${element(var.alias["zones_id"], count.index)}"
    evaluate_target_health = false
  }
}
