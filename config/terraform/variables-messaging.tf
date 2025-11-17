# ==============================================================================
# MESSAGING (SNS & SQS)
# ==============================================================================

variable "sns_topic_name" {
  description = "Name of the SNS topic used for ticket events"
  type        = string
  default     = "ticket-events"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue subscribed to the ticket topic"
  type        = string
  default     = "ticket-sql"
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for the ticket processing SQS queue"
  type        = number
  default     = 30
}

variable "sqs_message_retention_seconds" {
  description = "Message retention period for the ticket processing SQS queue"
  type        = number
  default     = 345600
}

variable "sqs_receive_wait_time_seconds" {
  description = "Long polling wait time for the ticket processing SQS queue"
  type        = number
  default     = 20
}

variable "sqs_max_receive_count" {
  description = "Number of receives before a message is moved to the DLQ"
  type        = number
  default     = 5
}

variable "sqs_dlq_message_retention_seconds" {
  description = "How long to keep messages in the DLQ"
  type        = number
  default     = 1209600
}
