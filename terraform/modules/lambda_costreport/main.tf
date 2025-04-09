resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_policy" "ce_cost_explorer_policy" {
  name        = "lambda-ce-cost-explorer-policy"
  description = "Allow Lambda to perform ce:GetCostAndUsage"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ce:GetCostAndUsage"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "lambda_ce_attach" {
  name       = "lambda-ce-policy-attachment"
  policy_arn = aws_iam_policy.ce_cost_explorer_policy.arn
  roles      = [aws_iam_role.lambda_exec_role.name]
}

resource "aws_sns_topic" "billing_report_topic" {
  name         = "billing-report-topic"
  display_name = "Billing Report Topic"
}

resource "aws_iam_role_policy" "lambda_costreport_sns_policy" {
  name = "lambda-costreport-sns-policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sns:Publish",
      Resource = aws_sns_topic.billing_report_topic.arn
    }]
  })
}

# Updated SNS Topic Subscription Resource
resource "aws_sns_topic_subscription" "email_subscription" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.billing_report_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-function/costreport"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "billing_report_lambda" {
  function_name    = "billingReportLambda"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_costreport.lambda_handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.billing_report_topic.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "ec2_termination_rule" {
  name          = "ec2-termination-rule"
  description   = "Trigger Lambda when an EC2 instance is terminated"
  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Instance State-change Notification"],
    "detail": {
      "state": ["shutting-down", "terminated"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_termination_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.billing_report_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_termination_rule.arn
}
