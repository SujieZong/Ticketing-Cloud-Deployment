variable "service_name" {
  description = "Base name for messaging resources"
  type        = string
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for SQS queue"
  type        = number
}

variable "message_retention_seconds" {
  description = "Message retention period for SQS queue"
  type        = number
}

variable "receive_wait_time_seconds" {
  description = "Receive wait time for long polling"
  type        = number
}

variable "max_receive_count" {
  description = "Number of times a message can be received before moving to DLQ"
  type        = number
}

variable "dlq_message_retention_seconds" {
  description = "Retention period for DLQ messages"
  type        = number
}
