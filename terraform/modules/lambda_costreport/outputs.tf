output "billing_report_lambda_arn" {
  value = aws_lambda_function.billing_report_lambda.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.billing_report_topic.arn
}

