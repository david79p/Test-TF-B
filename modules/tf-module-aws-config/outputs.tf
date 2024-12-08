output "recorder_id" {
  value = "${aws_config_configuration_recorder.this.id}"
}

output "recorder_name" {
  value = "${aws_config_configuration_recorder.this.name}"
}

output "delivery-channel" {
  value = "${aws_config_delivery_channel.this.name}"
}
