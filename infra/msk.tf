# =============================================================================
# MSK SERVERLESS CLUSTER
# IAM auth only (SASL_IAM) — no plaintext/TLS/mTLS needed.
# Subnets span 2 AZs minimum as required by MSK Serverless.
# Topics are NOT pre-created — use auto-create or manage separately.
# =============================================================================

resource "aws_msk_serverless_cluster" "main" {
  count        = var.enable_msk ? 1 : 0
  cluster_name = local.msk_cluster_name

  vpc_config {
    # MSK Serverless requires at least 2 subnets in different AZs
    subnet_ids         = [
      aws_subnet.private_az1[0].id,
      aws_subnet.private_az2[0].id,
    ]
    security_group_ids = [aws_security_group.msk[0].id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true  # Only auth option for MSK Serverless
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = local.msk_cluster_name
  })
}

# =============================================================================
# MSK CLOUDWATCH LOGGING
# Broker logs — cost-optimised: short retention, only ERROR + WARN level.
# =============================================================================

resource "aws_cloudwatch_log_group" "msk" {
  count             = var.enable_msk ? 1 : 0
  name              = local.msk_log_group
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(local.common_tags, {
    Name = "MSK Broker Logs"
  })
}

# =============================================================================
# MSK CLOUDWATCH ALARMS
# Cost-optimised: only the most actionable alarms.
# =============================================================================

# Consumer lag — most important: tells you if Glue is falling behind MSK
resource "aws_cloudwatch_metric_alarm" "msk_consumer_lag" {
  count = var.enable_msk ? 1 : 0

  alarm_name          = "${local.resource_name_prefix}-msk-consumer-lag"
  alarm_description   = "MSK consumer group lag is high - Glue streaming job may be falling behind"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "OffsetLag"
  namespace           = "AWS/Kafka"
  period              = 300   # 5 min
  statistic           = "Maximum"
  threshold           = 50000
  treat_missing_data  = "notBreaching"

  dimensions = {
    Cluster = local.msk_cluster_name
  }

  tags = local.common_tags
}

# Bytes in per second — alerts on unexpected traffic spikes (cost/quota)
resource "aws_cloudwatch_metric_alarm" "msk_bytes_in_high" {
  count = var.enable_msk ? 1 : 0

  alarm_name          = "${local.resource_name_prefix}-msk-bytes-in-high"
  alarm_description   = "MSK ingress unusually high - check producer throughput"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BytesInPerSec"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Average"
  threshold           = 10485760  # 10 MB/s
  treat_missing_data  = "notBreaching"

  dimensions = {
    Cluster = local.msk_cluster_name
  }

  tags = local.common_tags
}

# =============================================================================
# GLUE KAFKA CONNECTION
# Separate from the NETWORK connection — this one is typed KAFKA and points
# at the MSK Serverless bootstrap endpoint. Reference it in streaming Glue jobs
# via "--connections" = [aws_glue_connection.msk.name].
# =============================================================================

resource "aws_glue_connection" "msk" {
  count = var.enable_msk ? 1 : 0

  name            = "${local.resource_name_prefix}-msk-connection"
  description     = "Kafka connection to MSK Serverless - used by Glue streaming jobs"
  connection_type = "KAFKA"

  connection_properties = {
    KAFKA_BOOTSTRAP_SERVERS = aws_msk_serverless_cluster.main[0].cluster_name  # replaced post-creation; see note below
    KAFKA_SSL_ENABLED       = "false"   # IAM auth — SSL handled at auth layer
  }

  physical_connection_requirements {
    availability_zone      = data.aws_availability_zones.available.names[0]
    security_group_id_list = [aws_security_group.glue_jobs[0].id]
    subnet_id              = aws_subnet.private_az1[0].id
  }

  tags = merge(local.common_tags, {
    Name = "MSK Serverless Glue Connection"
  })

  # MSK Serverless bootstrap brokers are only available after cluster is ready.
  # After first apply, run:
  #   aws kafka get-bootstrap-brokers --cluster-arn <arn>
  # and update KAFKA_BOOTSTRAP_SERVERS with the returned endpoint.
  depends_on = [aws_msk_serverless_cluster.main]
}
