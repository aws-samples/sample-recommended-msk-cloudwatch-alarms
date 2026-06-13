
# ─────────────────────────────────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where the MSK cluster is deployed"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
}

variable "number_of_brokers" {
  description = "Number of brokers in the MSK cluster"
  type        = number
  default     = 3

  validation {
    condition     = var.number_of_brokers >= 1 && var.number_of_brokers <= 30
    error_message = "Number of brokers must be between 1 and 30."
  }
}

variable "notification_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

# ─── Thresholds ──────────────────────────────────────────────────────────────

variable "cpu_threshold" {
  description = "CPU utilization threshold percentage (CpuUser + CpuSystem)"
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

variable "heap_memory_threshold" {
  description = "Heap memory after GC threshold percentage"
  type        = number
  default     = 60

  validation {
    condition     = var.heap_memory_threshold > 0 && var.heap_memory_threshold <= 100
    error_message = "Heap memory threshold must be between 1 and 100."
  }
}

variable "disk_usage_threshold" {
  description = "Kafka data logs disk usage threshold percentage"
  type        = number
  default     = 85

  validation {
    condition     = var.disk_usage_threshold > 0 && var.disk_usage_threshold <= 100
    error_message = "Disk usage threshold must be between 1 and 100."
  }
}

# ─── Feature Toggles ─────────────────────────────────────────────────────────

variable "enable_traffic_shaping_alarms" {
  description = "Enable traffic shaping and bandwidth alarms"
  type        = bool
  default     = true
}

variable "enable_network_alarms" {
  description = "Enable network error alarms (Rx/Tx errors)"
  type        = bool
  default     = true
}

variable "enable_connection_alarms" {
  description = "Enable IAM connection limit alarms"
  type        = bool
  default     = true
}

