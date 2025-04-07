provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "simplyblock-terraform-state-bucket"
    key            = "infra"
    region         = "us-east-2"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

