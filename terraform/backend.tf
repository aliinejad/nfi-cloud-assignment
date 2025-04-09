terraform {
  backend "s3" {
    bucket         = "nfi-assignment-tfstate"
    key            = "nfi-assignment-tfstate"
    region         = "eu-central-1"
    encrypt        = true
  }
}
