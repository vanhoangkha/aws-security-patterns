# Automated Incident Response

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-high-severity"
  description = "Trigger on high severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "incident_response" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "TriggerIncidentResponse"
  arn       = aws_sfn_state_machine.incident_response.arn
  role_arn  = aws_iam_role.eventbridge.arn
}

resource "aws_sfn_state_machine" "incident_response" {
  name     = "incident-response-workflow"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "Automated Incident Response Workflow"
    StartAt = "ClassifyFinding"
    States = {
      ClassifyFinding = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.detail.type"
            StringMatches = "UnauthorizedAccess:*"
            Next          = "IsolateResource"
          },
          {
            Variable      = "$.detail.type"
            StringMatches = "Recon:*"
            Next          = "EnhanceMonitoring"
          }
        ]
        Default = "NotifySecurityTeam"
      }
      IsolateResource = {
        Type     = "Task"
        Resource = aws_lambda_function.isolate_resource.arn
        Next     = "CreateForensicSnapshot"
      }
      CreateForensicSnapshot = {
        Type     = "Task"
        Resource = aws_lambda_function.forensic_snapshot.arn
        Next     = "NotifySecurityTeam"
      }
      EnhanceMonitoring = {
        Type     = "Task"
        Resource = aws_lambda_function.enhance_monitoring.arn
        Next     = "NotifySecurityTeam"
      }
      NotifySecurityTeam = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.security_incidents.arn
          "Message.$" = "States.Format('Security Incident: {}', $.detail.type)"
        }
        End = true
      }
    }
  })
}

resource "aws_lambda_function" "isolate_resource" {
  filename      = data.archive_file.isolate.output_path
  function_name = "isolate-compromised-resource"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
}

resource "aws_lambda_function" "forensic_snapshot" {
  filename      = data.archive_file.forensic.output_path
  function_name = "create-forensic-snapshot"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 300
}

resource "aws_lambda_function" "enhance_monitoring" {
  filename      = data.archive_file.monitoring.output_path
  function_name = "enhance-monitoring"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
}

resource "aws_sns_topic" "security_incidents" {
  name = "security-incidents"
}

resource "aws_iam_role" "step_functions" {
  name = "incident-response-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  name = "sfn-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.isolate_resource.arn,
          aws_lambda_function.forensic_snapshot.arn,
          aws_lambda_function.enhance_monitoring.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.security_incidents.arn]
      }
    ]
  })
}

resource "aws_iam_role" "eventbridge" {
  name = "incident-response-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "start-sfn"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.incident_response.arn]
    }]
  })
}

resource "aws_iam_role" "lambda" {
  name = "incident-response-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "incident-response-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "isolate" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/isolate"
  output_path = "${path.module}/isolate.zip"
}

data "archive_file" "forensic" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/forensic"
  output_path = "${path.module}/forensic.zip"
}

data "archive_file" "monitoring" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/monitoring"
  output_path = "${path.module}/monitoring.zip"
}
