# Root User Activity Monitoring

resource "aws_cloudwatch_event_rule" "root_activity" {
  name        = "root-user-activity"
  description = "Monitor root user activity"

  event_pattern = jsonencode({
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_rule" "root_api" {
  name        = "root-user-api-calls"
  description = "Monitor root user API calls"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "root_activity_sns" {
  rule      = aws_cloudwatch_event_rule.root_activity.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.root_alerts.arn
}

resource "aws_cloudwatch_event_target" "root_api_sns" {
  rule      = aws_cloudwatch_event_rule.root_api.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.root_alerts.arn
}

resource "aws_sns_topic" "root_alerts" {
  name = "root-user-alerts"
}

resource "aws_sns_topic_policy" "root_alerts" {
  arn = aws_sns_topic.root_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.root_alerts.arn
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "root-user-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Root account usage detected"
  alarm_actions       = [aws_sns_topic.root_alerts.arn]
}

variable "notification_email" {
  type = string
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.root_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
