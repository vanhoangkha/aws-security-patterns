# Security Hub + Jira Integration

resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "securityhub-to-jira"
  description = "Send Security Hub findings to Jira"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.securityhub_findings.name
  target_id = "SendToJira"
  arn       = aws_lambda_function.jira_integration.arn
}

resource "aws_lambda_function" "jira_integration" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "securityhub-jira-integration"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      JIRA_URL     = var.jira_url
      JIRA_PROJECT = var.jira_project
      SECRET_NAME  = aws_secretsmanager_secret.jira_creds.name
    }
  }
}

resource "aws_secretsmanager_secret" "jira_creds" {
  name = "securityhub-jira-credentials"
}

resource "aws_iam_role" "lambda" {
  name = "securityhub-jira-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.jira_creds.arn]
    }]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

variable "jira_url" {
  type = string
}

variable "jira_project" {
  type = string
}
