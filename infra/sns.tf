# SNS Topic for Glue Job Notifications
resource "aws_sns_topic" "glue_job_notifications" {
  name = local.sns_topic_name

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Job Notifications"
    }
  )
}

resource "aws_sns_topic_subscription" "glue_job_email" {
  topic_arn = aws_sns_topic.glue_job_notifications.arn
  protocol  = "email"
  endpoint  = var.owner_email
}
