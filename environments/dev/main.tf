terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region  = var.aws_region
  profile = "labxp"
}

module "k8s_cluster" {
  source   = "../../modules/k8s_cluster"
  key_name = var.key_name
}

output "master_public_ip" {
  value = module.k8s_cluster.master_public_ip
}

output "worker_public_ips" {
  value = module.k8s_cluster.worker_public_ips
}

