provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "data_bucket" {
  bucket        = "dengue-csv-data"
  force_destroy = true
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role_pi3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3_access_policy_pi3"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject"],
        Resource = "arn:aws:s3:::dengue-csv-data/*"
      },
      {
        Effect = "Allow",
        Action = "s3:ListBucket",
        Resource = "arn:aws:s3:::dengue-csv-data"
      }
    ]
  })
}

variable "lambda_functions" {
  default = ["dados_get"]
}

resource "aws_lambda_function" "functions" {
  for_each = toset(var.lambda_functions)

  filename         = "${path.module}/lambda/zips/${each.key}.zip"
  function_name    = each.key
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "${each.key}.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60 # ⏱️ Timeout aumentado para 60 segundos
  memory_size      = 256 # 🔧 Mais memória acelera o processamento
  source_code_hash = filebase64sha256("${path.module}/lambda/zips/${each.key}.zip")
}

resource "aws_apigatewayv2_api" "api" {
  name          = "dengue-api"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "api_gateway_permissions" {
  for_each = aws_lambda_function.functions

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each               = aws_lambda_function.functions
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

locals {
  routes = {
    "GET /dados" = "dados_get"
  }
}

resource "aws_apigatewayv2_route" "routes" {
  for_each = local.routes

  api_id    = aws_apigatewayv2_api.api.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration[each.value].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}
