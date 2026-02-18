# AWS WAF Security Automations

module "waf_security_automations" {
  source  = "aws-ia/waf-security-automations/aws"
  version = "~> 3.0"

  activate_http_flood_protection          = true
  activate_scanner_probe_protection       = true
  activate_reputation_list_protection     = true
  activate_bad_bot_protection             = true
  activate_sql_injection_protection       = true
  activate_xss_protection                 = true

  endpoint_type = var.endpoint_type # ALB, CLOUDFRONT, or APIGATEWAY

  # Rate limiting
  request_threshold           = var.request_threshold
  request_threshold_by_country = var.request_threshold_by_country

  # Logging
  access_log_bucket = var.log_bucket

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "main" {
  count        = var.resource_arn != "" ? 1 : 0
  resource_arn = var.resource_arn
  web_acl_arn  = module.waf_security_automations.web_acl_arn
}

variable "endpoint_type" {
  type    = string
  default = "ALB"
}

variable "request_threshold" {
  type    = number
  default = 2000
}

variable "request_threshold_by_country" {
  type    = number
  default = 50
}

variable "log_bucket" {
  type = string
}

variable "resource_arn" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "web_acl_arn" {
  value = module.waf_security_automations.web_acl_arn
}
