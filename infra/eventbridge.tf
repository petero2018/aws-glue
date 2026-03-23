# EventBridge Rule for Glue Job State Changes
resource "aws_cloudwatch_event_rule" "glue_job_state_change" {
  name        = "${local.resource_name_prefix}-job-state-change"
  description = "Capture all Glue job state changes"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Job State Change Rule"
    }
  )
}

# EventBridge Target: Send to SNS
resource "aws_cloudwatch_event_target" "glue_job_state_sns" {
  rule      = aws_cloudwatch_event_rule.glue_job_state_change.name
  target_id = "GlueJobStateSNS"
  arn       = aws_sns_topic.glue_job_notifications.arn

  dead_letter_config {
    arn = aws_sqs_queue.glue_job_events_dlq.arn
  }
}

# EventBridge Target: Send to SQS
resource "aws_cloudwatch_event_target" "glue_job_state_sqs" {
  rule      = aws_cloudwatch_event_rule.glue_job_state_change.name
  target_id = "GlueJobStateSQS"
  arn       = aws_sqs_queue.glue_job_events.arn

  dead_letter_config {
    arn = aws_sqs_queue.glue_job_events_dlq.arn
  }
}

# EventBridge Rule for Glue Job Failures Only
resource "aws_cloudwatch_event_rule" "glue_job_failure" {
  name        = "${local.resource_name_prefix}-job-failure"
  description = "Capture failed Glue jobs"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      state = ["FAILED", "TIMEOUT"]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Job Failure Rule"
    }
  )
}

# EventBridge Target for Failures: SNS
resource "aws_cloudwatch_event_target" "glue_job_failure_sns" {
  rule      = aws_cloudwatch_event_rule.glue_job_failure.name
  target_id = "GlueJobFailureSNS"
  arn       = aws_sns_topic.glue_job_notifications.arn
}
