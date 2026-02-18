# Network Firewall Alerts to Slack

resource "aws_cloudwatch_log_group" "firewall" {
  name              = "/aws/network-firewall/alerts"
  retention_in_days = 30
}

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = var.firewall_arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

resource "aws_cloudwatch_log_subscription_filter" "slack" {
  name            = "network-firewall-to-slack"
  log_group_name  = aws_cloudwatch_log_group.firewall.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.slack_notifier.arn
}

resource "aws_lambda_function" "slack_notifier" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "network-firewall-slack-notifier"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.firewall.arn}:*"
}

resource "aws_iam_role" "lambda" {
  name = "network-firewall-slack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

variable "firewall_arn" {
  type = string
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}
