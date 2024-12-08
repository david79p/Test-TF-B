#######################################################################################################################
# Outputs for Route53 Module
#######################################################################################################################

output "zone_id" {
  value       = ["${aws_route53_zone.this.*.id}"]
  description = "The ID for the Hosted Zone"
}

output "zone_name" {
  value       = ["${aws_route53_zone.this.*.name}"]
  description = "The name of the Hosted Zone"
}

output "name_servers" {
  value       = "${aws_route53_zone.this.*.name_servers}"
  description = "The name servers of the Hosted Zone"
}
