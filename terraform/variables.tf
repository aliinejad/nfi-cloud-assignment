variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to deploy resources in"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets - one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets - one per AZ"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "custom_ami_id" {
  type = string
}

variable "overnight_notification_emails" {
  description = "List of email addresses to receive notifications"
  type        = list(string)
}
variable "notification_emails" {
  description = "List of email addresses to receive notifications"
  type        = list(string)
}
