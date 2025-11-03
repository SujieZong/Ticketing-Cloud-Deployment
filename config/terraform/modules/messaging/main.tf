# SNS Topic for order processing events
resource "aws_sns_topic" "order_events" {
  name = var.sns_topic_name

  tags = {
    Name = "${var.service_name}-sns-topic"
  }
}

# SQS Queue for order processing
resource "aws_sqs_queue" "order_queue" {
  name = var.sqs_queue_name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  tags = {
    Name = "${var.service_name}-sqs-queue"
  }
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "order_queue_policy" {
  queue_url = aws_sqs_queue.order_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.order_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_events.arn
          }
        }
      }
    ]
  })
}

# SNS Topic Subscription to SQS Queue
resource "aws_sns_topic_subscription" "order_events_sqs" {
  topic_arn            = aws_sns_topic.order_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.order_queue.arn
  raw_message_delivery = true
}

# IAM Policy for ECS tasks to access SNS and SQS
resource "aws_iam_policy" "messaging_access" {
  name = "${var.service_name}-messaging-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = aws_sns_topic.order_events.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.order_queue.arn
      }
    ]
  })
}