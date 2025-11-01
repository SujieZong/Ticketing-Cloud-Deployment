variable "service_name" {
  description = "Base name for messaging resources"
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