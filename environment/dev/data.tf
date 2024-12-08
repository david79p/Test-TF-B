#######################################################################################################################
# Development Environment
#######################################################################################################################

###################
# mgmt remote state
###################
data "terraform_remote_state" "mgmt_account" {
  backend = "s3"

  config {
    bucket   = "156460081782-tfstate"
    key      = "mgmt/terraform.tfstate"
    region   = "eu-west-1"
    role_arn = "arn:aws:iam::156460081782:role/Jenkins"
  }
}
