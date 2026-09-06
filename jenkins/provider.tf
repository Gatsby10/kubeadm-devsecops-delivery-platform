provider "aws" {
  region  = "eu-west-3"
  profile = "default"
}

terraform {
  backend "s3" {
    bucket         = "kubadm-shok-shop"
    dynamodb_table = "sock-shop-state-lock-table"
    key            = "jenkins/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "default"
    #use_lockfile   = true
    encrypt        = true
  }
}
