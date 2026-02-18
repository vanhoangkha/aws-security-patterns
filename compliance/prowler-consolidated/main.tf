# Prowler Consolidated Report - Multi-Account

resource "aws_codebuild_project" "prowler" {
  name         = "prowler-security-scan"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.reports.id
    path     = "prowler-reports"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "ACCOUNTS"
      value = join(",", var.account_ids)
    }

    environment_variable {
      name  = "ROLE_NAME"
      value = var.cross_account_role_name
    }

    environment_variable {
      name  = "OUTPUT_BUCKET"
      value = aws_s3_bucket.reports.id
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - pip install prowler
        build:
          commands:
            - |
              for ACCOUNT in $(echo $ACCOUNTS | tr ',' ' '); do
                echo "Scanning account: $ACCOUNT"
                prowler aws \
                  -R arn:aws:iam::$ACCOUNT:role/$ROLE_NAME \
                  -M json-ocsf csv html \
                  -o /tmp/prowler-$ACCOUNT \
                  --severity critical high medium
              done
        post_build:
          commands:
            - |
              # Consolidate reports
              python3 << 'EOF'
              import json
              import glob
              import os

              all_findings = []
              for f in glob.glob('/tmp/prowler-*/prowler-output-*.ocsf.json'):
                  with open(f) as file:
                      findings = json.load(file)
                      all_findings.extend(findings)

              # Summary by account
              summary = {}
              for finding in all_findings:
                  account = finding.get('cloud', {}).get('account', {}).get('uid', 'unknown')
                  severity = finding.get('severity', 'unknown')
                  if account not in summary:
                      summary[account] = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
                  summary[account][severity.lower()] = summary[account].get(severity.lower(), 0) + 1

              with open('/tmp/consolidated-report.json', 'w') as f:
                  json.dump({'summary': summary, 'total_findings': len(all_findings)}, f, indent=2)
              EOF
            - aws s3 sync /tmp/ s3://$OUTPUT_BUCKET/prowler-reports/$(date +%Y-%m-%d)/
      artifacts:
        files:
          - '**/*'
        base-directory: /tmp
    BUILDSPEC
  }
}

resource "aws_s3_bucket" "reports" {
  bucket_prefix = "prowler-reports-"
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "prowler-weekly-scan"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "codebuild" {
  rule     = aws_cloudwatch_event_rule.schedule.name
  arn      = aws_codebuild_project.prowler.arn
  role_arn = aws_iam_role.eventbridge.arn
}

resource "aws_iam_role" "codebuild" {
  name = "prowler-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "prowler-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = [for id in var.account_ids : "arn:aws:iam::${id}:role/${var.cross_account_role_name}"]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = ["${aws_s3_bucket.reports.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "eventbridge" {
  name = "prowler-eventbridge-role"

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
  name = "start-codebuild"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["codebuild:StartBuild"]
      Resource = [aws_codebuild_project.prowler.arn]
    }]
  })
}

variable "account_ids" {
  type        = list(string)
  description = "List of AWS account IDs to scan"
}

variable "cross_account_role_name" {
  type    = string
  default = "ProwlerSecurityAudit"
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 2 ? * SUN *)"
}
