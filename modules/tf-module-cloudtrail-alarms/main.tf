resource "aws_cloudwatch_log_metric_filter" "filter" {
  count = "${var.toggle == "on" ? length(var.alarms) : 0}"

  name    = "${lookup(var.alarms[count.index],"alarm_name")}"
  pattern = "${lookup(var.alarms[count.index],"pattern")}"

  //log_group_name = "${lookup(var.alarms[count.index],"log_group_name")}"
  log_group_name = "${var.cloudwatch_log_group_name}"

  metric_transformation {
    name      = "${lookup(var.alarms[count.index],"metric_name")}"
    namespace = "${lookup(var.alarms[count.index],"metric_namespace","CISBenchmark")}"
    value     = "${lookup(var.alarms[count.index],"metric_value","1")}"
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm" {
  count               = "${var.toggle == "on" ? length(var.alarms) : 0}"
  alarm_name          = "${lookup(var.alarms[count.index],"alarm_name")}"
  comparison_operator = "${lookup(var.alarms[count.index],"comparison_operator","GreaterThanOrEqualToThreshold")}"
  evaluation_periods  = "${lookup(var.alarms[count.index],"evaluation_periods","1")}"
  metric_name         = "${lookup(var.alarms[count.index],"metric_name")}"
  namespace           = "${lookup(var.alarms[count.index],"metric_namespace","CISBenchmark")}"
  period              = "${lookup(var.alarms[count.index],"period","60")}"
  statistic           = "${lookup(var.alarms[count.index],"statistic","Sum")}"
  threshold           = "${lookup(var.alarms[count.index],"threshold","1")}"
  alarm_description   = "${lookup(var.alarms[count.index],"description","")}"
  alarm_actions       = ["${compact(var.cloudwatch_alarm_actions)}"]
  treat_missing_data  = "${lookup(var.alarms[count.index],"treat_missing_data","notBreaching")}"
}
