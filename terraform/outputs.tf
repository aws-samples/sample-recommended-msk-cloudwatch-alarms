output "sns_topic_arn" {
  description = "ARN of the SNS topic used for alarm notifications"
  value       = local.sns_topic_arn != "" ? local.sns_topic_arn : "No notification target configured"
}

output "notification_warning" {
  description = "Check if alarm notifications are properly configured"
  value = (
    var.existing_sns_topic_arn != "" ? "OK - Using existing SNS topic" :
    var.notification_email != "" ? "OK - SNS topic created, confirm email subscription" :
    "WARNING: No notification_email or existing_sns_topic_arn provided. Alarms will trigger but NOT send notifications."
  )
}

output "cluster_name" {
  description = "Name of the monitored MSK cluster"
  value       = var.cluster_name
}

output "cluster_arn" {
  description = "ARN of the monitored MSK cluster"
  value       = var.cluster_arn
}

output "brokers_monitored" {
  description = "Number of brokers with per-broker alarms"
  value       = var.number_of_brokers
}

output "total_alarms_created" {
  description = "Total number of CloudWatch alarms created"
  value = (
    2 +                                                                              # cluster-level
    (var.number_of_brokers * 6) +                                                    # always-on per-broker
    (var.enable_traffic_shaping_alarms ? var.number_of_brokers * 3 : 0) +            # traffic shaping
    (var.enable_network_alarms ? var.number_of_brokers * 2 : 0) +                    # network errors
    (var.enable_connection_alarms ? var.number_of_brokers * 1 : 0)                   # IAM connections
  )
}

output "alarm_dashboard_url" {
  description = "URL to view the alarms in CloudWatch console"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#alarmsV2:?~(search~(query~(source~(alarmName~(value~(prefix~(0~'MSK-${var.cluster_name})))))(sort~(column~'default)(direction~'desc))))"
}

data "aws_region" "current" {}
