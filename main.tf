provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "simplyblock-terraform-state-bucket"
    key            = "infra"
    region         = "us-east-2"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}

resource "aws_lambda_function" "instance_stopper" {
  function_name = "InstanceStopper"

  runtime = "python3.8"
  handler = "index.handler"

  filename      = "${path.module}/instanceStopper/instance_stopper.zip"
  source_code_hash = filebase64sha256("${path.module}/instanceStopper/instance_stopper.zip")

  role = aws_iam_role.lambda_exec_role.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "instance_stopper_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "every_twelve_hours" {
  name = "instance_stopper_schedule"
  description = "Trigger every 1 hours"
  schedule_expression = "cron(0 */11 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.every_twelve_hours.name
  arn  = aws_lambda_function.instance_stopper.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.instance_stopper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_twelve_hours.arn
}
