
# ─────────────────────────────────────────────────────────────────────────────
# Amazon MSK Recommended CloudWatch Alarms - Terraform
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# SNS Topic for Alarm Notifications
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "msk_alarms" {
  name              = "MSK-${var.cluster_name}-Alarms"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.msk_alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ─────────────────────────────────────────────────────────────────────────────
# Cluster-Level Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "active_controller_count" {
  alarm_name          = "MSK-${var.cluster_name}-ActiveControllerCount"
  alarm_description   = "MSK cluster has no active controller"
  namespace           = "AWS/Kafka"
  metric_name         = "ActiveControllerCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "offline_partitions" {
  alarm_name          = "MSK-${var.cluster_name}-OfflinePartitionsCount"
  alarm_description   = "MSK cluster has offline partitions"
  namespace           = "AWS/Kafka"
  metric_name         = "OfflinePartitionsCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-Broker Alarms
# ─────────────────────────────────────────────────────────────────────────────

# CPU Utilization (CpuUser + CpuSystem via Metric Math)
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count               = var.number_of_brokers
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-CPUUtilization"
  alarm_description   = "Broker ${count.index + 1} CPU utilization exceeds ${var.cpu_threshold}%"
  evaluation_periods  = 3
  threshold           = var.cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "cpu_total"
    expression  = "cpu_user + cpu_system"
    label       = "Total CPU"
    return_data = true
  }

  metric_query {
    id = "cpu_user"
    metric {
      metric_name = "CpuUser"
      namespace   = "AWS/Kafka"
      period      = 300
      stat        = "Average"
      dimensions = {
        "Cluster Name" = var.cluster_name
        "Broker ID"    = tostring(count.index + 1)
      }
    }
  }

  metric_query {
    id = "cpu_system"
    metric {
      metric_name = "CpuSystem"
      namespace   = "AWS/Kafka"
      period      = 300
      stat        = "Average"
      dimensions = {
        "Cluster Name" = var.cluster_name
        "Broker ID"    = tostring(count.index + 1)
      }
    }
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# Heap Memory After GC
resource "aws_cloudwatch_metric_alarm" "heap_memory" {
  count               = var.number_of_brokers
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-HeapMemoryAfterGC"
  alarm_description   = "Broker ${count.index + 1} heap memory after GC exceeds ${var.heap_memory_threshold}%"
  namespace           = "AWS/Kafka"
  metric_name         = "HeapMemoryAfterGC"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.heap_memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# Kafka Data Logs Disk Used
resource "aws_cloudwatch_metric_alarm" "disk_usage" {
  count               = var.number_of_brokers
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-KafkaDataLogsDiskUsed"
  alarm_description   = "Broker ${count.index + 1} disk usage exceeds ${var.disk_usage_threshold}%"
  namespace           = "AWS/Kafka"
  metric_name         = "KafkaDataLogsDiskUsed"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.disk_usage_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# Under-Replicated Partitions
resource "aws_cloudwatch_metric_alarm" "under_replicated_partitions" {
  count               = var.number_of_brokers
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-UnderReplicatedPartitions"
  alarm_description   = "Broker ${count.index + 1} has under-replicated partitions"
  namespace           = "AWS/Kafka"
  metric_name         = "UnderReplicatedPartitions"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# Volume Queue Length
resource "aws_cloudwatch_metric_alarm" "volume_queue_length" {
  count               = var.number_of_brokers
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-VolumeQueueLength"
  alarm_description   = "Broker ${count.index + 1} EBS volume queue length is high"
  namespace           = "AWS/Kafka"
  metric_name         = "VolumeQueueLength"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Traffic Shaping Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "traffic_shaping" {
  count               = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-TrafficShaping"
  alarm_description   = "Broker ${count.index + 1} is experiencing network throttling"
  namespace           = "AWS/Kafka"
  metric_name         = "TrafficShaping"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "bw_in_allowance_exceeded" {
  count               = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-BwInAllowanceExceeded"
  alarm_description   = "Broker ${count.index + 1} inbound bandwidth allowance exceeded"
  namespace           = "AWS/Kafka"
  metric_name         = "BwInAllowanceExceeded"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "bw_out_allowance_exceeded" {
  count               = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-BwOutAllowanceExceeded"
  alarm_description   = "Broker ${count.index + 1} outbound bandwidth allowance exceeded"
  namespace           = "AWS/Kafka"
  metric_name         = "BwOutAllowanceExceeded"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Network Error Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "network_rx_errors" {
  count               = var.enable_network_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-NetworkRxErrors"
  alarm_description   = "Broker ${count.index + 1} has network receive errors"
  namespace           = "AWS/Kafka"
  metric_name         = "NetworkRxErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "network_tx_errors" {
  count               = var.enable_network_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-NetworkTxErrors"
  alarm_description   = "Broker ${count.index + 1} has network transmit errors"
  namespace           = "AWS/Kafka"
  metric_name         = "NetworkTxErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Optional: IAM Connection Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "iam_too_many_connections" {
  count               = var.enable_connection_alarms ? var.number_of_brokers : 0
  alarm_name          = "MSK-${var.cluster_name}-Broker${count.index + 1}-IAMTooManyConnections"
  alarm_description   = "Broker ${count.index + 1} IAM connection limit exceeded"
  namespace           = "AWS/Kafka"
  metric_name         = "IAMTooManyConnections"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = [aws_sns_topic.msk_alarms.arn]
  ok_actions    = [aws_sns_topic.msk_alarms.arn]
}

