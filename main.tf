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
  
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  post_fix               = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  spline_agent_file_path = "asset/lib/spark-3.1-spline-agent-bundle_2.12-0.7.4.jar"
}

output "api_url" {
  value = aws_apigatewayv2_stage.data_lineage.invoke_url
}

output "neptune_endpoint" {
  value = aws_neptune_cluster.default.endpoint
}