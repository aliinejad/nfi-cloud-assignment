output "overnight_alarm_topic_arn" {
  description = "ARN of the Overnight Alarm SNS Topic"
  value       = aws_sns_topic.overnight_alarm_topic.arn
}
