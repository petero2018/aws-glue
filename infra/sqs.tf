# SQS Queue for Glue job event notifications
resource "aws_sqs_queue" "glue_job_events" {
  name                      = local.sqs_queue_name
  delay_seconds             = 0
  max_message_size          = 262144  # 256 KB
  message_retention_seconds = var.sqs_message_retention_seconds
  receive_wait_time_seconds = 0

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Job Events Queue"
    }
  )
}

# SQS Queue Policy to allow EventBridge to send messages
resource "aws_sqs_queue_policy" "glue_job_events" {
  queue_url = aws_sqs_queue.glue_job_events.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.glue_job_events.arn
      }
    ]
  })
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "glue_job_events_dlq" {
  name                      = local.sqs_dlq_name
  message_retention_seconds = 1209600  # 14 days

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Job Events DLQ"
    }
  )
}
