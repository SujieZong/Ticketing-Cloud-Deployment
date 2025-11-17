output "warning_topic_arn" {
  description = "SNS topic that receives monitoring warnings"
  value       = aws_sns_topic.warning.arn
}
