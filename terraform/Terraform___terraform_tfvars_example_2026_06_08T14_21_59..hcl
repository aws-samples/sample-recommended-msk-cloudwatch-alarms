
# ─────────────────────────────────────────────────────────────────────────────
# Copy this file to terraform.tfvars and fill in your values
# ─────────────────────────────────────────────────────────────────────────────

aws_region         = "us-east-1"
cluster_name       = "my-msk-cluster"
number_of_brokers  = 3
notification_email = "your-email@example.com"

# Thresholds (optional - defaults shown)
# cpu_threshold         = 60
# heap_memory_threshold = 60
# disk_usage_threshold  = 85

# Feature toggles (optional - defaults shown)
# enable_traffic_shaping_alarms = true
# enable_network_alarms         = true
# enable_connection_alarms      = true

