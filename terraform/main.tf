provider "aws" {
  region = var.region
}

module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "autoscaling" {
  source         = "./modules/autoscaling"
  vpc_subnet_ids = module.vpc.public_subnet_ids
  custom_ami_id  = var.custom_ami_id
}

module "lambda_costreport" {
  source             = "./modules/lambda_costreport"
  notification_emails = var.notification_emails
}

module "overnight_alarm" {
  source                         = "./modules/overnight_alarm"
  overnight_notification_emails   = var.overnight_notification_emails
}