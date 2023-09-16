resource "aws_apigatewayv2_api" "api" {
  name          = "syren-rpc"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.api.id

  name        = "default"
  auto_deploy = true
}

resource "aws_cloudwatch_log_group" "api" {
  name = "/aws/api-gw/${aws_apigatewayv2_api.api.name}"

  retention_in_days = 14
}
