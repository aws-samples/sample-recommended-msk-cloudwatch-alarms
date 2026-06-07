# Sample Amazon MSK Production-Ready CloudWatch Alarms

This sample code repository provides AWS CloudFormation templates for deploying production-ready Amazon CloudWatch alarms for Amazon Managed Streaming for Apache Kafka (Amazon MSK) clusters. The templates create per-broker and cluster-level alarms based on AWS best practices as outlined in the [MSK Best Practices documentation](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html) and the AWS Big Data Blog post [Set up production-ready monitoring for Amazon MSK using CloudWatch alarms](https://aws.amazon.com/blogs/big-data/set-up-production-ready-monitoring-for-amazon-msk-using-cloudwatch-alarms/).

## Features

- **Two deployment modes:**
  - **ARN-based:** Deploy alarms for a specific MSK cluster using its ARN
  - **Tag-based:** Deploy alarms across multiple MSK clusters matching specific tags (e.g., `Environment=prod`)
- **Comprehensive alarm coverage** across all critical metric categories:
  - Broker health and cluster availability
  - Resource utilization (CPU, memory, disk)
  - Topic and partition activity
  - Client connections
  - Network bandwidth and traffic shaping
- **Configurable thresholds** via CloudFormation parameters
- **SNS notification** integration for alarm actions
- **Multi-environment support** (prod, dev, staging) via tagging

## Architecture

### ARN-based deployment (single cluster)

```

  ┌──────────────────────────────────────────────────────────────────┐
  │                      CloudFormation Stack                        │
  ├──────────────────────────────────────────────────────────────────┤
  │                                                                  │
  │  ┌─────────────┐       ┌─────────────────────────────────────┐   │
  │  │  Lambda Fn  │──────►│ CloudWatch Alarms (per broker)      │   │
  │  │(Custom Res) │       │  - Broker1-CPUUtilization           │   │
  │  └──────┬──────┘       │  - Broker1-KafkaDataLogsDiskUsed    │   │
  │         │              │  - Broker1-HeapMemoryAfterGC        │   │
  │         │              │  - Broker1-TrafficShaping           │   │
  │         │              │  - Broker1-NetworkRxErrors          │   │
  │         │              │  - ... (repeated per broker)        │   │
  │         │              └─────────────────┬───────────────────┘   │
  │         │                                │                       │
  │         │              ┌─────────────────▼───────────────────┐   │
  │         └─────────────►│ CloudWatch Alarms (cluster-level)   │   │
  │                        │  - ActiveControllerCount            │   │
  │                        │  - OfflinePartitionsCount           │   │
  │  ┌─────────────┐       └─────────────────┬───────────────────┘   │
  │  │  IAM Role   │                         │                       │
  │  └─────────────┘                         ▼                       │
  │                        ┌─────────────────────────────────────┐   │
  │                        │ SNS Topic ──► Email / PagerDuty     │   │
  │                        └─────────────────────────────────────┘   │
  │                                                                  │
  └──────────────────────────────────────────────────────────────────┘

```

### Tag-based deployment (multi-cluster)

```

  ┌──────────────────────────────────────────────────────────────┐
  │                    CloudFormation Stack                      │
  ├──────────────────────────────────────────────────────────────┤
  │                                                              │
  │  ┌─────────────┐    ┌─────────────────┐                      │
  │  │ EventBridge │───►│   Lambda Fn     │                      │
  │  │  (hourly)   │    │ (Discovery +    │                      │
  │  └─────────────┘    │  Alarm Mgmt)    │                      │
  │                     └────────┬────────┘                      │
  │  ┌─────────────┐             │                               │
  │  │ Custom Res  │────────────►│                               │
  │  │ (on deploy) │             │                               │
  │  └─────────────┘             ▼                               │
  │                     ┌─────────────────┐                      │
  │                     │    MSK API      │                      │
  │                     │ (discover by    │                      │
  │                     │  tag match)     │                      │
  │                     └────────┬────────┘                      │
  │                              │                               │
  │          ┌───────────────────┼───────────────────┐           │
  │          ▼                   ▼                   ▼           │
  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐     │
  │  │ Cluster A     │  │ Cluster B     │  │ Cluster C     │     │
  │  │ (per broker)  │  │ (per broker)  │  │ (per broker)  │     │
  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘     │
  │          └───────────────────┼───────────────────┘           │
  │                              ▼                               │
  │                  ┌───────────────────────┐                   │
  │                  │  SNS Topic ──► Email  │                   │
  │                  └───────────────────────┘                   │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘

```

## Templates

| Template | Description |
|----------|-------------|
| `templates/msk-alarms-by-arn.yaml` | Deploy alarms for a single MSK cluster identified by ARN |
| `templates/msk-alarms-by-tags.yaml` | Deploy alarms using a Lambda-backed custom resource that discovers clusters by tags |

## Prerequisites

- An AWS account with an active Amazon MSK cluster
- Permissions to create CloudFormation stacks, CloudWatch alarms, SNS topics, and (for the tag-based template) Lambda functions and IAM roles
- Access to [AWS CloudShell](https://console.aws.amazon.com/cloudshell/)

## Deployment

### Step 1: Download templates in CloudShell

Open [AWS CloudShell](https://console.aws.amazon.com/cloudshell/) in your account and run:

```bash
# Download templates from this repository
wget -q https://raw.githubusercontent.com/aws-samples/msk-cloudwatch-alarms/main/templates/msk-alarms-by-arn.yaml
wget -q https://raw.githubusercontent.com/aws-samples/msk-cloudwatch-alarms/main/templates/msk-alarms-by-tags.yaml
```

### Step 2: Deploy alarms

#### Option A: Deploy for a specific cluster (by ARN)

Replace the parameter values with your cluster details.

```bash
# Set your cluster details
CLUSTER_NAME="my-msk-cluster"
CLUSTER_ARN="arn:aws:kafka:us-east-1:123456789012:cluster/my-msk-cluster/abc-123-xyz"
NUM_BROKERS=3
NOTIFICATION_EMAIL="ops-team@example.com"

# Deploy the stack
aws cloudformation create-stack \
  --stack-name msk-alarms-${CLUSTER_NAME} \
  --template-body file://msk-alarms-by-arn.yaml \
  --parameters \
    ParameterKey=ClusterName,ParameterValue=${CLUSTER_NAME} \
    ParameterKey=ClusterArn,ParameterValue=${CLUSTER_ARN} \
    ParameterKey=NumberOfBrokers,ParameterValue=${NUM_BROKERS} \
    ParameterKey=NotificationEmail,ParameterValue=${NOTIFICATION_EMAIL} \
  --capabilities CAPABILITY_IAM

# Wait for stack creation to complete
aws cloudformation wait stack-create-complete --stack-name msk-alarms-${CLUSTER_NAME}

# Check stack status
aws cloudformation describe-stacks --stack-name msk-alarms-${CLUSTER_NAME} \
  --query 'Stacks[0].StackStatus' --output text
```

#### Option B: Deploy for clusters matching tags (multi-cluster)

This option discovers all MSK clusters with a specific tag and creates alarms for each. Useful for deploying across all production or development clusters at once.

```bash
# Set your tag filter
TAG_KEY="Environment"
TAG_VALUE="production"
NOTIFICATION_EMAIL="ops-team@example.com"

# Deploy the stack
aws cloudformation create-stack \
  --stack-name msk-alarms-${TAG_VALUE} \
  --template-body file://msk-alarms-by-tags.yaml \
  --parameters \
    ParameterKey=TagKey,ParameterValue=${TAG_KEY} \
    ParameterKey=TagValue,ParameterValue=${TAG_VALUE} \
    ParameterKey=NotificationEmail,ParameterValue=${NOTIFICATION_EMAIL} \
  --capabilities CAPABILITY_NAMED_IAM

# Wait for stack creation to complete
aws cloudformation wait stack-create-complete --stack-name msk-alarms-${TAG_VALUE}

# Check stack outputs (shows discovered clusters and alarms created)
aws cloudformation describe-stacks --stack-name msk-alarms-${TAG_VALUE} \
  --query 'Stacks[0].Outputs' --output table
```

### Step 3: Confirm SNS subscription

After deployment, check your email for an SNS subscription confirmation message and confirm it. Alarms will not deliver notifications until the subscription is confirmed.

## Parameters

### Common Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NotificationEmail` | *(required)* | Email address for alarm notifications |
| `NumberOfBrokers` | `3` | Number of brokers in the cluster (ARN template only) |
| `CPUThreshold` | `60` | CPU utilization alarm threshold (%) |
| `HeapMemoryThreshold` | `60` | Heap memory after GC alarm threshold (%) |
| `DiskUsageThreshold` | `85` | Kafka data logs disk usage alarm threshold (%) |
| `EnableConnectionAlarms` | `true` | Enable connection count alarms |
| `EnableNetworkAlarms` | `true` | Enable network error alarms |
| `EnableTrafficShapingAlarms` | `true` | Enable traffic shaping alarms |

### ARN Template Parameters

| Parameter | Description |
|-----------|-------------|
| `ClusterName` | Name of the MSK cluster |
| `ClusterArn` | Full ARN of the MSK cluster |

### Tag Template Parameters

| Parameter | Description |
|-----------|-------------|
| `TagKey` | Tag key to filter MSK clusters |
| `TagValue` | Tag value to filter MSK clusters |

## Alarms Deployed

| Alarm | Metric | Condition | Severity |
|-------|--------|-----------|----------|
| Active Controller Count | `ActiveControllerCount` | Sum < 1 for 5 min | Critical |
| Offline Partitions | `OfflinePartitionsCount` | > 0 for 5 min | Critical |
| Under-Replicated Partitions | `UnderReplicatedPartitions` | > 0 for 15 min | High |
| Under Min ISR Partitions | `UnderMinIsrPartitionCount` | > 0 for 5 min | High |
| CPU Utilization | `CpuUser + CpuSystem` | > 60% for 15 min | Warning |
| Heap Memory After GC | `HeapMemoryAfterGC` | > 60% for 15 min | Warning |
| Disk Usage | `KafkaDataLogsDiskUsed` | ≥ 85% for 5 min | High |
| Volume Queue Length | `VolumeQueueLength` | > 10 for 15 min | Warning |
| Traffic Shaping | `TrafficShaping` | > 0 for 1 min | Critical |
| BW In Allowance Exceeded | `BwInAllowanceExceeded` | > 0 for 5 min | High |
| BW Out Allowance Exceeded | `BwOutAllowanceExceeded` | > 0 for 5 min | High |
| Network Rx Errors | `NetworkRxErrors` | > 0 for 5 min | Warning |
| Network Tx Errors | `NetworkTxErrors` | > 0 for 5 min | Warning |
| IAM Too Many Connections | `IAMTooManyConnections` | > 0 for 5 min | Warning |
| Consumer Lag (optional) | `MaxOffsetLag` | > 1000 for 15 min | Warning |

## Customizing Thresholds

All alarm thresholds are exposed as CloudFormation parameters. Override them during deployment:

```bash
aws cloudformation create-stack \
  --stack-name msk-alarms-custom \
  --template-body file://msk-alarms-by-arn.yaml \
  --parameters \
    ParameterKey=ClusterName,ParameterValue=my-cluster \
    ParameterKey=ClusterArn,ParameterValue=arn:aws:kafka:us-east-1:123456789012:cluster/my-cluster/abc123 \
    ParameterKey=NumberOfBrokers,ParameterValue=6 \
    ParameterKey=NotificationEmail,ParameterValue=ops@example.com \
    ParameterKey=CPUThreshold,ParameterValue=70 \
    ParameterKey=DiskUsageThreshold,ParameterValue=80 \
  --capabilities CAPABILITY_IAM
```

## Updating an Existing Stack

To update thresholds or add/remove optional alarms on an existing deployment:

```bash
aws cloudformation update-stack \
  --stack-name msk-alarms-my-msk-cluster \
  --template-body file://msk-alarms-by-arn.yaml \
  --parameters \
    ParameterKey=ClusterName,UsePreviousValue=true \
    ParameterKey=ClusterArn,UsePreviousValue=true \
    ParameterKey=NumberOfBrokers,UsePreviousValue=true \
    ParameterKey=NotificationEmail,UsePreviousValue=true \
    ParameterKey=CPUThreshold,ParameterValue=70 \
  --capabilities CAPABILITY_IAM
```

## Testing

We recommend deploying to a test cluster first:

1. Deploy the stack against a non-production cluster
2. Validate alarms appear in the CloudWatch console
3. Generate artificial load to trigger alarm thresholds
4. Confirm SNS notifications are received
5. Tune thresholds based on your workload patterns

## Clean Up

```bash
aws cloudformation delete-stack --stack-name msk-alarms-prod-cluster

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name msk-alarms-prod-cluster
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
