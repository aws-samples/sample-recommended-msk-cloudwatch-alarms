terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {}

locals {
  alarm_prefix = "MSK-${var.cluster_name}"
  broker_ids   = [for i in range(1, var.number_of_brokers + 1) : tostring(i)]

  # Determine SNS topic ARN for alarm actions
  sns_topic_arn = var.existing_sns_topic_arn != "" ? var.existing_sns_topic_arn : (
    var.notification_email != "" ? aws_sns_topic.alarms[0].arn : ""
  )
  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []

  common_tags = merge(var.tags, {
    ManagedBy  = "terraform"
    MSKCluster = var.cluster_name
    Purpose    = "MSKMonitoring"
  })
}

# ============================================================
# SNS Topic for Alarm Notifications
# ============================================================

resource "aws_sns_topic" "alarms" {
  count = var.existing_sns_topic_arn == "" && var.notification_email != "" ? 1 : 0

  name              = "${local.alarm_prefix}-Alarms"
  display_name      = "MSK Alarms - ${var.cluster_name}"
  kms_master_key_id = "alias/aws/sns"
  tags              = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.existing_sns_topic_arn == "" && var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================================
# CLUSTER-LEVEL ALARMS (dimension: Cluster Name only)
# ============================================================

resource "aws_cloudwatch_metric_alarm" "active_controller_count" {
  alarm_name          = "${local.alarm_prefix}-ActiveControllerCount"
  alarm_description   = "CRITICAL: Active controller count is not 1. Only one controller should be active at any time."
  namespace           = "AWS/Kafka"
  metric_name         = "ActiveControllerCount"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "offline_partitions_count" {
  alarm_name          = "${local.alarm_prefix}-OfflinePartitionsCount"
  alarm_description   = "CRITICAL: Cluster has offline partitions. No active leader exists — data is temporarily unavailable."
  namespace           = "AWS/Kafka"
  metric_name         = "OfflinePartitionsCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# ============================================================
# PER-BROKER ALARMS (dimensions: Cluster Name, Broker ID)
# ============================================================

# --- CPU Utilization (metric math: CpuUser + CpuSystem) ---
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-CPUUtilization"
  alarm_description   = "WARNING: Broker ${count.index + 1} CPU (CpuUser + CpuSystem) exceeds ${var.cpu_threshold}%."
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "cpu_user"
    return_data = false

    metric {
      namespace   = "AWS/Kafka"
      metric_name = "CpuUser"
      period      = 300
      stat        = "Average"
      dimensions = {
        "Cluster Name" = var.cluster_name
        "Broker ID"    = tostring(count.index + 1)
      }
    }
  }

  metric_query {
    id          = "cpu_system"
    return_data = false

    metric {
      namespace   = "AWS/Kafka"
      metric_name = "CpuSystem"
      period      = 300
      stat        = "Average"
      dimensions = {
        "Cluster Name" = var.cluster_name
        "Broker ID"    = tostring(count.index + 1)
      }
    }
  }

  metric_query {
    id          = "total_cpu"
    expression  = "cpu_user + cpu_system"
    label       = "Broker ${count.index + 1} Total CPU"
    return_data = true
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Heap Memory After GC ---
resource "aws_cloudwatch_metric_alarm" "heap_memory_after_gc" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-HeapMemoryAfterGC"
  alarm_description   = "WARNING: Broker ${count.index + 1} heap memory after GC exceeds ${var.heap_memory_threshold}%. Risk of OOM."
  namespace           = "AWS/Kafka"
  metric_name         = "HeapMemoryAfterGC"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.heap_memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Kafka Data Logs Disk Used ---
resource "aws_cloudwatch_metric_alarm" "disk_usage" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-KafkaDataLogsDiskUsed"
  alarm_description   = "HIGH: Broker ${count.index + 1} disk usage exceeds ${var.disk_usage_threshold}%. Risk of data loss."
  namespace           = "AWS/Kafka"
  metric_name         = "KafkaDataLogsDiskUsed"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = var.disk_usage_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Under-Replicated Partitions ---
resource "aws_cloudwatch_metric_alarm" "under_replicated_partitions" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-UnderReplicatedPartitions"
  alarm_description   = "HIGH: Broker ${count.index + 1} has under-replicated partitions."
  namespace           = "AWS/Kafka"
  metric_name         = "UnderReplicatedPartitions"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Under Min ISR Partition Count ---
resource "aws_cloudwatch_metric_alarm" "under_min_isr" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-UnderMinIsrPartitionCount"
  alarm_description   = "HIGH: Broker ${count.index + 1} has partitions below min ISR. Potential data loss risk."
  namespace           = "AWS/Kafka"
  metric_name         = "UnderMinIsrPartitionCount"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Volume Queue Length ---
resource "aws_cloudwatch_metric_alarm" "volume_queue_length" {
  count = var.number_of_brokers

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-VolumeQueueLength"
  alarm_description   = "WARNING: Broker ${count.index + 1} EBS volume queue length elevated. Possible disk I/O bottleneck."
  namespace           = "AWS/Kafka"
  metric_name         = "VolumeQueueLength"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Traffic Shaping ---
resource "aws_cloudwatch_metric_alarm" "traffic_shaping" {
  count = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-TrafficShaping"
  alarm_description   = "CRITICAL: Broker ${count.index + 1} experiencing network throttling. Packets being dropped or queued."
  namespace           = "AWS/Kafka"
  metric_name         = "TrafficShaping"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- BwInAllowanceExceeded ---
resource "aws_cloudwatch_metric_alarm" "bw_in_exceeded" {
  count = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-BwInAllowanceExceeded"
  alarm_description   = "HIGH: Broker ${count.index + 1} inbound bandwidth exceeded maximum."
  namespace           = "AWS/Kafka"
  metric_name         = "BwInAllowanceExceeded"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- BwOutAllowanceExceeded ---
resource "aws_cloudwatch_metric_alarm" "bw_out_exceeded" {
  count = var.enable_traffic_shaping_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-BwOutAllowanceExceeded"
  alarm_description   = "HIGH: Broker ${count.index + 1} outbound bandwidth exceeded maximum."
  namespace           = "AWS/Kafka"
  metric_name         = "BwOutAllowanceExceeded"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Network Rx Errors ---
resource "aws_cloudwatch_metric_alarm" "network_rx_errors" {
  count = var.enable_network_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-NetworkRxErrors"
  alarm_description   = "WARNING: Broker ${count.index + 1} has network receive errors."
  namespace           = "AWS/Kafka"
  metric_name         = "NetworkRxErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- Network Tx Errors ---
resource "aws_cloudwatch_metric_alarm" "network_tx_errors" {
  count = var.enable_network_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-NetworkTxErrors"
  alarm_description   = "WARNING: Broker ${count.index + 1} has network transmit errors."
  namespace           = "AWS/Kafka"
  metric_name         = "NetworkTxErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}

# --- IAM Too Many Connections ---
resource "aws_cloudwatch_metric_alarm" "iam_too_many_connections" {
  count = var.enable_connection_alarms ? var.number_of_brokers : 0

  alarm_name          = "${local.alarm_prefix}-Broker${count.index + 1}-IAMTooManyConnections"
  alarm_description   = "WARNING: Broker ${count.index + 1} exceeded IAM connection limit (100). New connections blocked."
  namespace           = "AWS/Kafka"
  metric_name         = "IAMTooManyConnections"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = var.cluster_name
    "Broker ID"    = tostring(count.index + 1)
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.common_tags
}
