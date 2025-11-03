output "alb_dns_name" {
  description = "DNS name of the shared Application Load Balancer"
  value       = aws_lb.shared.dns_name
}

output "alb_arn" {
  description = "ARN of the shared Application Load Balancer"
  value       = aws_lb.shared.arn
}

output "target_group_arns" {
  description = "Map of service names to their target group ARNs"
  value       = { for k, v in aws_lb_target_group.services : k => v.arn }
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "listener_arn" {
  description = "ARN of the HTTP listener (deprecated, use http_listener_arn)"
  value       = aws_lb_listener.http.arn
}
