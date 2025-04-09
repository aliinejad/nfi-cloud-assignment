variable "vpc_subnet_ids" {
  description = "List of subnet IDs for the ASG"
  type        = list(string)
}

variable "custom_ami_id" {
  description = "Custom Ubuntu AMI ID"
  type        = string
}

