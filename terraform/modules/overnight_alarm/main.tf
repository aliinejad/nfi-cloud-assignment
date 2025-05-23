resource "aws_sns_topic" "overnight_alarm_topic" {
  name = "overnight-alarm-topic"
}

resource "aws_sns_topic_subscription" "overnight_email_sub" {
  for_each  = toset(var.overnight_notification_emails)
  topic_arn = aws_sns_topic.overnight_alarm_topic.arn
  protocol  = "email"
  endpoint  = each.value
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

data "archive_file" "overnight_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-function/overnight-ec2-checker"  # Ensure overnight_checker.py is here
  output_path = "${path.module}/overnight_lambda.zip"
}

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

resource "aws_cloudwatch_event_rule" "overnight_rule" {
  name                = "overnight-lambda-trigger"
  description         = "Trigger the overnight checker Lambda function daily at 8:00 AM UTC"
  schedule_expression = "cron(0 8 * * ? *)"
}

resource "aws_cloudwatch_event_target" "overnight_target" {
  rule      = aws_cloudwatch_event_rule.overnight_rule.name
  target_id = "overnightChecker"
  arn       = aws_lambda_function.overnight_checker.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_for_overnight" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.overnight_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.overnight_rule.arn
}
