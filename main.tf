terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region  = "eu-west-1"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data aws_vpc "current" {
  id = var.vpc_id
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.current.id
}

locals {
  post_fix               = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  spline_agent_file_path = "asset/lib/spark-2.4-spline-agent-bundle_2.11-0.5.6.jar"
}

resource aws_security_group "default" {
  name = "sg_default"
  ingress {
    from_port  = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = data.aws_vpc.current.id
}

output "api_url" {
  value = aws_apigatewayv2_stage.data_lineage.invoke_url
}

output "neptune_endpoint" {
  value = aws_neptune_cluster.default.endpoint
}