resource "aws_launch_template" "app" {
  name_prefix   = "nfi-app-launch-"
  image_id      = var.custom_ami_id
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "asg" {
  name                = "nfi-auto-scaling-group"
  desired_capacity    = 0
  min_size            = 0
  max_size            = 2
  vpc_zone_identifier = var.vpc_subnet_ids

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  desired_capacity       = 2
  min_size               = 2
  max_size               = 2
  recurrence             = "0 6 * * *"
}

resource "aws_cloudwatch_event_rule" "scale_down_rule" {
  name                = "scale_down_rule"
  schedule_expression = "cron(0 18 * * ? *)"
}

resource "aws_iam_role" "lambda_role" {
  name = "asg_scale_down_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "asg_scale_down_lambda_policy"
  description = "Policy for ASG scale-down Lambda function."
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeInstances"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-function/asg-scaledown"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "scale_down_function" {
  function_name = "asg_scale_down_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "asg_scale_down_function.handler"
  runtime       = "python3.8"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      AUTO_SCALING_GROUP = aws_autoscaling_group.asg.name
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_down_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down_rule.arn
}

resource "aws_cloudwatch_event_target" "scale_down_target" {
  rule      = aws_cloudwatch_event_rule.scale_down_rule.name
  target_id = "scaleDownFunction"
  arn       = aws_lambda_function.scale_down_function.arn
}
