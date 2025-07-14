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

terraform {
  backend "s3" {
    bucket = "aer-tf"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}
