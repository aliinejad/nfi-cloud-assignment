# Module: terraform/modules/overnight_alarm/main.tf

# Create an SNS Topic for overnight notifications
resource "aws_sns_topic" "overnight_alarm_topic" {
  name = "overnight-alarm-topic"
}

# Create an email subscription for the SNS topic (email to be passed in via variable)
resource "aws_sns_topic_subscription" "overnight_email_sub" {
  topic_arn = aws_sns_topic.overnight_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.overnight_notification_email
}

resource "aws_iam_role_policy" "overnight_sns_publish_policy" {
  name = "overnight-sns-publish-policy"
  role = aws_iam_role.overnight_lambda_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
         "Effect": "Allow",
         "Action": "sns:Publish",
         "Resource": "arn:aws:sns:eu-central-1:176779409247:overnight-alarm-topic"
      }
    ]
  })
}


# IAM Role for the Overnight Checker Lambda function
resource "aws_iam_role" "overnight_lambda_role" {
  name = "overnight_lambda_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

# Attach the AWSLambdaBasicExecutionRole for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "overnight_lambda_basic" {
  role       = aws_iam_role.overnight_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "overnight_ec2_policy" {
  name = "overnight_ec2_policy"
  role = aws_iam_role.overnight_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ec2:DescribeInstances",
        Resource = "*"
      }
    ]
  })
}

# Archive the Overnight Checker Lambda function code
data "archive_file" "overnight_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-function/overnight-ec2-checker"  # Ensure overnight_checker.py is here
  output_path = "${path.module}/overnight_lambda.zip"
}

# Create the Overnight Checker Lambda Function
resource "aws_lambda_function" "overnight_checker" {
  function_name    = "overnightChecker"
  role             = aws_iam_role.overnight_lambda_role.arn
  handler          = "overnight_checker.lambda_handler"
  runtime          = "python3.8"
  filename         = data.archive_file.overnight_lambda_zip.output_path
  source_code_hash = data.archive_file.overnight_lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      OVERNIGHT_SNS_TOPIC_ARN = aws_sns_topic.overnight_alarm_topic.arn
    }
  }
}

# CloudWatch Event Rule to trigger the Overnight Checker daily (example: 8:00 AM UTC)
resource "aws_cloudwatch_event_rule" "overnight_rule" {
  name                = "overnight-lambda-trigger"
  description         = "Trigger the overnight checker Lambda function daily at 8:00 AM UTC"
  schedule_expression = "cron(0 8 * * ? *)"
}

# CloudWatch Event Target linking rule to Lambda
resource "aws_cloudwatch_event_target" "overnight_target" {
  rule      = aws_cloudwatch_event_rule.overnight_rule.name
  target_id = "overnightChecker"
  arn       = aws_lambda_function.overnight_checker.arn
}

# Allow CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch_for_overnight" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.overnight_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.overnight_rule.arn
}
