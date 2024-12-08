#######################################################################################################################
# Development Environment
#######################################################################################################################

provider "aws" {
  region  = "${var.region}"
  version = ">=1.40"

  assume_role {
    role_arn = "arn:aws:iam::156460081782:role/Jenkins"
  }
}

terraform {
  backend "s3" {
    bucket         = "156460081782-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "156460081782-tfstate"
    role_arn       = "arn:aws:iam::156460081782:role/Jenkins"
  }
}

variable "region" {
  default = "eu-west-1"
}
