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
