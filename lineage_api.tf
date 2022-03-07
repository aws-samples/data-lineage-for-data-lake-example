################################################################
# Container Image
################################################################

resource "aws_ecr_repository" "repo" {
  name = "data_lineage"
}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  ecr_image_tag = "latest"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "src/lambda"
  output_path = "lambda.zip"
}

resource "null_resource" "ecr_image" {
  triggers = {
    src_hash = data.archive_file.lambda.output_sha
  }
  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region ${local.region} \
        | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com
      cd ${path.module}/src/lambda
      docker build -t ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag} --platform=linux/amd64 .
      docker push ${aws_ecr_repository.repo.repository_url}:${local.ecr_image_tag}
    EOF
  }
}

data aws_ecr_image lambda_image {
  depends_on      = [
    null_resource.ecr_image
  ]
  repository_name = aws_ecr_repository.repo.name
  image_tag       = local.ecr_image_tag
}


################################################################
# Lambda functions
################################################################

locals {
  api_stage = "dev"
}

resource aws_iam_role lambda_execution_lineage {
  name                = "LineageLambdaExecutionRole"
  assume_role_policy  = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Action": "sts:AssumeRole",
           "Principal": {
               "Service": "lambda.amazonaws.com"
           },
           "Effect": "Allow"
       }
   ]
}
 EOF
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/NeptuneFullAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    aws_iam_policy.glue_read_only.arn
  ]
}

resource "aws_iam_policy" "glue_read_only" {
  name        = "GlueReadOnlyAccess"
  description = "GlueReadOnlyAccess"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "glue:Get*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource aws_lambda_function producer {
  depends_on    = [
    null_resource.ecr_image
  ]
  function_name = "DataLineageProducer"
  role          = aws_iam_role.lambda_execution_lineage.arn
  timeout       = 300
  image_uri     = "${aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.lambda_image.id}"
  package_type  = "Image"
  environment {
    variables = {
      API_STAGE                = local.api_stage,
      NEPTUNE_CLUSTER_ENDPOINT = aws_neptune_cluster.default.endpoint,
      NEPTUNE_CLUSTER_PORT     = aws_neptune_cluster.default.port,
    }
  }
  vpc_config {
    subnet_ids         = data.aws_subnet_ids.default.ids
    security_group_ids = [aws_security_group.default.id]
  }
  image_config {
    command = ["producer.lambda_handler"]
  }
}

resource aws_lambda_function consumer {
  depends_on    = [
    null_resource.ecr_image
  ]
  function_name = "DataLineageConsumer"
  role          = aws_iam_role.lambda_execution_lineage.arn
  timeout       = 300
  image_uri     = "${aws_ecr_repository.repo.repository_url}@${data.aws_ecr_image.lambda_image.id}"
  package_type  = "Image"
  environment {
    variables = {
      API_STAGE                = local.api_stage,
      NEPTUNE_CLUSTER_ENDPOINT = aws_neptune_cluster.default.endpoint,
      NEPTUNE_CLUSTER_PORT     = aws_neptune_cluster.default.port,
    }
  }
  vpc_config {
    subnet_ids         = data.aws_subnet_ids.default.ids
    security_group_ids = [aws_security_group.default.id]
  }
  image_config {
    command = ["consumer.lambda_handler"]
  }
}


################################################################
# API Gateway
################################################################
resource "aws_apigatewayv2_api" "data_lineage" {
  name          = "data_lineage"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.data_lineage.name}"
  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "data_lineage" {
  api_id      = aws_apigatewayv2_api.data_lineage.id
  name        = local.api_stage
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    }
    )
  }
}

resource "aws_apigatewayv2_integration" "producer" {
  api_id                 = aws_apigatewayv2_api.data_lineage.id
  integration_uri        = aws_lambda_function.producer.invoke_arn
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "consumer" {
  api_id                 = aws_apigatewayv2_api.data_lineage.id
  integration_uri        = aws_lambda_function.consumer.invoke_arn
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "permission_api_gw_producer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.data_lineage.execution_arn}/*/*"
}

resource "aws_lambda_permission" "permission_api_gw_consumer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consumer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.data_lineage.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "producer_status" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "HEAD /status"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_route" "producer_execution_plans" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "POST /execution-plans"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_route" "producer_execution_events" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "POST /execution-events"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_route" "producer_execution_failure" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "POST /execution-failure"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_route" "consumer_status" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.consumer.id}"
}

resource "aws_apigatewayv2_route" "consumer_jobs" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "GET /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.consumer.id}"
}

resource "aws_apigatewayv2_route" "consumer_job" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "GET /job/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.consumer.id}"
}

resource "aws_apigatewayv2_route" "consumer_dag" {
  api_id    = aws_apigatewayv2_api.data_lineage.id
  route_key = "GET /dag/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.consumer.id}"
}