resource "aws_launch_template" "app" {
  name_prefix   = "nfi-app-launch-"
  image_id      = var.custom_ami_id
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "asg" {
  name                 = "nfi-auto-scaling-group"
  desired_capacity     = 0
  min_size             = 0
  max_size             = 2
  vpc_zone_identifier  = var.vpc_subnet_ids

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
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

resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  desired_capacity       = 0
  min_size               = 0
  max_size               = 0
  recurrence             = "0 18 * * *"  # 6:00 PM UTC
}

