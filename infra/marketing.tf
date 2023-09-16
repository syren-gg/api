resource "aws_sns_topic" "marketing" {
  name              = "syren-marketing"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_iam_policy" "marketing_publish" {
  name = "PublishMarketingEvents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"

        Action = [
          "sns:Publish",
        ]

        Resource = [
          aws_sns_topic.marketing.arn
        ]
      }
    ]
  })
}
