terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env         = var.env
      team        = var.team
      cost-centre = var.cost_centre
      ticket      = var.ticket
      managed-by  = "terraform"
    }
  }
}
