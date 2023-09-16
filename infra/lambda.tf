
locals {
  functions = {
    "SubscribeMailingList-v1" = {
      type = "api"

      extra_policies = [
        aws_iam_policy.marketing_publish,
      ]

      environment_variables = {
        MARKETING_EVENTS_TOPIC_ARN = aws_sns_topic.marketing.arn
      }
    }

    "MailjetMailingListSubscriptionNotifier-v1" = {
      type      = "sns"
      topic_arn = aws_sns_topic.marketing.arn

      environment_variables = {
        MJ_API_KEY    = var.mailjet_api_key
        MJ_API_SECRET = var.mailjet_api_secret
      }
    }
  }

  api_functions = { for name, func in local.functions : name => func if func.type == "api" }
  sns_functions = { for name, func in local.functions : name => func if func.type == "sns" }

  functions_policies = flatten([
    for function_key, function_data in local.functions : [
      for policy in try(function_data.extra_policies, []) : {
        function_key = function_key
        policy_arn   = policy.arn
        policy_name  = policy.name
      }
    ]
  ])
}

resource "aws_iam_role" "lambda" {
  for_each = local.functions

  name = "lambda-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role" {
  for_each   = local.functions
  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "extra_policy" {
  for_each = {
    for i, item in local.functions_policies :
    "${item.function_key}-${item.policy_name}" => item
  }

  policy_arn = each.value.policy_arn
  role       = aws_iam_role.lambda[each.value.function_key].name
}

data "archive_file" "lambda" {
  for_each    = local.functions
  type        = "zip"
  source_dir  = "../src/functions/${each.key}"
  output_path = "./pkg/functions/${each.key}.zip"
}

resource "aws_lambda_function" "lambda" {
  for_each = local.functions

  function_name = "syren-${each.key}"
  handler       = "index.handler"
  role          = aws_iam_role.lambda[each.key].arn

  filename         = data.archive_file.lambda[each.key].output_path
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  runtime          = "nodejs18.x"

  environment {
    variables = try(each.value.environment_variables, {})
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.functions
  name     = "/aws/lambda/${aws_lambda_function.lambda[each.key].function_name}"

  retention_in_days = 30
}

# SNS integration #############################################################

resource "aws_lambda_permission" "sns" {
  for_each      = local.sns_functions
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[each.key].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value.topic_arn
}

resource "aws_sns_topic_subscription" "lambda" {
  for_each  = local.sns_functions
  topic_arn = each.value.topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda[each.key].arn
}

# API Gateway integration #####################################################

resource "aws_apigatewayv2_integration" "lambda" {
  for_each         = local.api_functions
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.lambda[each.key].invoke_arn
}

resource "aws_apigatewayv2_route" "lambda_rpc" {
  for_each  = local.api_functions
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /${each.key}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}

resource "aws_lambda_permission" "api" {
  for_each      = local.api_functions
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
