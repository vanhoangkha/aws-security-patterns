# Auto-remediate Unencrypted RDS Instances

resource "aws_config_config_rule" "rds_encryption" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
}

resource "aws_cloudwatch_event_rule" "rds_noncompliant" {
  name = "rds-encryption-noncompliant"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = [aws_config_config_rule.rds_encryption.name]
      complianceType = ["NON_COMPLIANT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "remediation" {
  rule      = aws_cloudwatch_event_rule.rds_noncompliant.name
  target_id = "TriggerRemediation"
  arn       = aws_lambda_function.remediate_rds.arn
}

resource "aws_lambda_function" "remediate_rds" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "remediate-unencrypted-rds"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 300
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      KMS_KEY_ID = var.kms_key_id
      SNS_TOPIC  = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediate_rds.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_noncompliant.arn
}

resource "aws_iam_role" "lambda" {
  name = "rds-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "rds_access" {
  name = "rds-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:CreateDBSnapshot",
          "rds:CopyDBSnapshot",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:CreateGrant", "kms:DescribeKey"]
        Resource = var.kms_key_id != "" ? var.kms_key_id : "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.alerts.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sns_topic" "alerts" {
  name = "rds-encryption-alerts"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

variable "kms_key_id" {
  type    = string
  default = ""
}
