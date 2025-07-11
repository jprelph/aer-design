terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
  }
}

provider "aws" {
  alias   = "primary"
  region  = var.region
}

provider "aws" {
  alias   = "secondary"
  region  = var.sec_region
}
