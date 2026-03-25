# CloudWatch Logging and Monitoring for AWS Glue Infrastructure
# Centralized log groups and alarms for Glue jobs, crawlers, MSK, and Athena

# ============================================================================
# Glue Jobs and Crawlers Logging
# ============================================================================

# CloudWatch Log Group for Glue Jobs
resource "aws_cloudwatch_log_group" "glue_jobs" {
  name              = local.glue_job_log_group
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Jobs Logs"
    }
  )
}

# CloudWatch Log Group for Glue Crawler
resource "aws_cloudwatch_log_group" "glue_crawlers" {
  name              = local.glue_crawler_log_group
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Crawlers Logs"
    }
  )
}

# CloudWatch Log Stream for Jobs
resource "aws_cloudwatch_log_stream" "glue_jobs_stream" {
  name           = "job-runs"
  log_group_name = aws_cloudwatch_log_group.glue_jobs.name
}

# ============================================================================
# Glue Jobs Monitoring
# ============================================================================

# CloudWatch Alarm for monitoring Glue job failures
resource "aws_cloudwatch_metric_alarm" "glue_job_duration" {
  alarm_name          = "${local.resource_name_prefix}-job-duration-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "AWS/Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when Glue jobs have failed tasks"

  dimensions = {
    JobName = "glue-job"
  }

  tags = local.common_tags
}

# ============================================================================
# MSK Monitoring
# ============================================================================
# Note: MSK log groups and alarms are defined in msk.tf

# ============================================================================
# Athena Query Logging and Monitoring
# ============================================================================

# CloudWatch Log Group for Athena Queries
resource "aws_cloudwatch_log_group" "athena_query_logs" {
  name              = "/aws/athena/${local.resource_name_prefix}"
  retention_in_days = 14

  tags = merge(
    local.common_tags,
    {
      Name = "Athena Query Logs"
    }
  )
}

# CloudWatch Alarm: Failed queries
resource "aws_cloudwatch_metric_alarm" "athena_failed_queries" {
  alarm_name          = "${local.resource_name_prefix}-athena-failed-queries"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EngineExecutionTime"
  namespace           = "AWS/Athena"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Athena queries fail"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkGroup = aws_athena_workgroup.glue_engineering.name
  }

  tags = local.common_tags
}

# CloudWatch Alarm: Data scanned (cost control)
resource "aws_cloudwatch_metric_alarm" "athena_data_scanned" {
  alarm_name          = "${local.resource_name_prefix}-athena-data-scanned-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DataScannedInBytes"
  namespace           = "AWS/Athena"
  period              = 300
  statistic           = "Sum"
  threshold           = 10737418240  # 10 GB in bytes
  alarm_description   = "Alert when queries scan >10GB (cost control)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkGroup = aws_athena_workgroup.glue_engineering.name
  }

  tags = local.common_tags
}

# CloudWatch Alarm: Query execution time (performance)
resource "aws_cloudwatch_metric_alarm" "athena_slow_queries" {
  alarm_name          = "${local.resource_name_prefix}-athena-slow-queries"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EngineExecutionTime"
  namespace           = "AWS/Athena"
  period              = 300
  statistic           = "Maximum"
  threshold           = 60000  # 60 seconds in milliseconds
  alarm_description   = "Alert when queries take >60 seconds"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkGroup = aws_athena_workgroup.glue_engineering.name
  }

  tags = local.common_tags
}
