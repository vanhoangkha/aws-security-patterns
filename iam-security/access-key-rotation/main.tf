# IAM Access Key Rotation Monitoring

resource "aws_config_config_rule" "iam_access_key_rotation" {
  name = "iam-access-key-rotation-check"

  source {
    owner             = "AWS"
    source_identifier = "ACCESS_KEYS_ROTATED"
  }

  input_parameters = jsonencode({
    maxAccessKeyAge = var.max_key_age_days
  })

  maximum_execution_frequency = "TwentyFour_Hours"
}

resource "aws_cloudwatch_event_rule" "config_compliance" {
  name        = "iam-key-rotation-noncompliant"
  description = "Detect non-compliant IAM access keys"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName  = [aws_config_config_rule.iam_access_key_rotation.name]
      complianceType  = ["NON_COMPLIANT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

resource "aws_sns_topic" "security_alerts" {
  name = "iam-security-alerts"
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.security_alerts.arn
    }]
  })
}

variable "max_key_age_days" {
  type    = number
  default = 90
}

variable "notification_email" {
  type = string
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
