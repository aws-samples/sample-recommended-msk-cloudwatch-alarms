# Terraform Deployment

This directory contains Terraform configurations for deploying recommended CloudWatch alarms for Amazon MSK clusters.

## Advantage over CloudFormation

Terraform handles broker loops natively with `count` — no Lambda or Custom Resource needed. All alarms are created as standard Terraform resources with full plan/apply visibility.

## Files

| File | Description |
|------|-------------|
| `main.tf` | Provider configuration and alarm resources |
| `variables.tf` | Input variables with defaults matching AWS best practices |
| `outputs.tf` | Stack outputs (SNS topic ARN, alarm count) |

## Usage

```bash
cd terraform/

terraform init

terraform plan \
  -var="cluster_name=my-msk-cluster" \
  -var="cluster_arn=arn:aws:kafka:us-east-1:123456789012:cluster/my-msk-cluster/abc123" \
  -var="number_of_brokers=3" \
  -var="notification_email=ops-team@example.com"

terraform apply \
  -var="cluster_name=my-msk-cluster" \
  -var="cluster_arn=arn:aws:kafka:us-east-1:123456789012:cluster/my-msk-cluster/abc123" \
  -var="number_of_brokers=3" \
  -var="notification_email=ops-team@example.com"
```

Alternatively, create a `terraform.tfvars` file:

```hcl
cluster_name       = "my-msk-cluster"
cluster_arn        = "arn:aws:kafka:us-east-1:123456789012:cluster/my-msk-cluster/abc123"
number_of_brokers  = 3
notification_email = "ops-team@example.com"
```

Then simply run:

```bash
terraform init
terraform plan
terraform apply
```

## Clean Up

```bash
terraform destroy
```
