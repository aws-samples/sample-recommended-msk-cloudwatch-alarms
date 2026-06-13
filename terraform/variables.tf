variable "cluster_name" {
  description = "Name of the Amazon MSK cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]+$", var.cluster_name))
    error_message = "Cluster name must contain only alphanumeric characters and hyphens."
  }
}

variable "cluster_arn" {
  description = "Full ARN of the Amazon MSK cluster"
  type        = string

  validation {
    condition     = can(regex("^arn:aws[\\w-]*:kafka:", var.cluster_arn))
    error_message = "Must be a valid MSK cluster ARN."
  }
}

variable "number_of_brokers" {
  description = "Number of brokers in the MSK cluster. Per-broker alarms are created for each."
  type        = number
  default     = 3

  validation {
    condition     = var.number_of_brokers >= 1 && var.number_of_brokers <= 30
    error_message = "Number of brokers must be between 1 and 30."
  }
}

variable "notification_email" {
  description = "Email address for alarm notifications. Leave empty if using existing_sns_topic_arn."
  type        = string
  default     = ""
}

variable "existing_sns_topic_arn" {
  description = "ARN of an existing SNS topic for alarm notifications. Overrides notification_email."
  type        = string
  default     = ""
}

variable "cpu_threshold" {
  description = "CPU utilization alarm threshold (percentage). AWS recommends keeping total CPU under 60%."
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_threshold >= 1 && var.cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

variable "heap_memory_threshold" {
  description = "Heap memory after GC alarm threshold (percentage)."
  type        = number
  default     = 60

  validation {
    condition     = var.heap_memory_threshold >= 1 && var.heap_memory_threshold <= 100
    error_message = "Heap memory threshold must be between 1 and 100."
  }
}

variable "disk_usage_threshold" {
  description = "Kafka data logs disk usage alarm threshold (percentage)."
  type        = number
  default     = 85

  validation {
    condition     = var.disk_usage_threshold >= 1 && var.disk_usage_threshold <= 100
    error_message = "Disk usage threshold must be between 1 and 100."
  }
}

variable "enable_connection_alarms" {
  description = "Enable IAM connection limit alarms."
  type        = bool
  default     = true
}

variable "enable_network_alarms" {
  description = "Enable network error alarms."
  type        = bool
  default     = true
}

variable "enable_traffic_shaping_alarms" {
  description = "Enable traffic shaping (network throttling) alarms."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
