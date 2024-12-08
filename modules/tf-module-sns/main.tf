resource "aws_sns_topic" "this" {
  count = "${length(var.sns_topic_names)}"
  name  = "${element(var.sns_topic_names, count.index)}"
}
