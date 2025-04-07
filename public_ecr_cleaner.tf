resource "aws_lambda_function" "public_ecr_cleaner" {
  function_name = "publicECRCleaner"

  runtime = "python3.8"
  handler = "public_ecr_cleaner.lambda_handler"

  filename         = "${path.module}/publicECRCleaner/public_ecr_cleaner.zip"
  source_code_hash = filebase64sha256("${path.module}/publicECRCleaner/public_ecr_cleaner.zip")

  role    = aws_iam_role.publci_ecr_cleaner_lambda_exec_role.arn
  timeout = 600 # 10 mins
  environment {
    variables = {
      REGISTRY_ID = var.registry_id
      BATCH_DELETE_SIZE = var.batch_delete_size
    }
  }
}

resource "aws_iam_role" "publci_ecr_cleaner_lambda_exec_role" {
  name = "public_ecr_cleaner_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })

  inline_policy {
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ecr-public:DescribeRepositories",
            "ecr-public:DescribeImages",
            "ecr-public:BatchDeleteImage"
          ]
          Effect : "Allow"
          Resource : "*"
        }
      ]
    })
  }
}

resource "aws_iam_policy" "public_ecr_cleaner_policy" {
  name        = "public_ecr_cleaner_lambda_execution_policy"
  description = "public_ecr_cleaner_lambda_execution_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
        "ecr-public:DescribeRepositories",
        "ecr-public:DescribeImages",
        "ecr-public:BatchDeleteImage"
        ]
        Effect : "Allow"
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "public_ecr_cleaner_policy_attach" {
  role       = aws_iam_role.publci_ecr_cleaner_lambda_exec_role.name
  policy_arn = aws_iam_policy.public_ecr_cleaner_policy.arn
}

resource "aws_cloudwatch_event_rule" "every_five_am_utc" {
  name                = "public_ecr_cleaner_schedule"
  description         = "Runs on schedule 5am UTC"
  schedule_expression = "cron(0 5 * * ? *)"
}

resource "aws_cloudwatch_event_target" "public_ecr_cleaner_lambda" {
  rule = aws_cloudwatch_event_rule.every_five_am_utc.name
  arn  = aws_lambda_function.public_ecr_cleaner.arn
}

resource "aws_lambda_permission" "public_ecr_cleaner_allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.public_ecr_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_five_am_utc.arn
}
