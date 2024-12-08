provider "aws" {
  region = "${var.region}"

  assume_role {
    role_arn = "arn:aws:iam::156460081782:role/Jenkins"
  }

  version = ">=1.40"
}

terraform {
  backend "s3" {
    bucket         = "156460081782-tfstate"
    key            = "global/terraform.tfstate"
    region         = "eu-west-1"
    role_arn       = "arn:aws:iam::156460081782:role/Jenkins"
    dynamodb_table = "156460081782-tfstate"
  }
}

variable "region" {
  default = "eu-west-1"
}
