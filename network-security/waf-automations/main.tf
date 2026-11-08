# AWS WAF Security Automations
#
# Deploys the AWS Solutions "Security Automations for AWS WAF" CloudFormation
# template (there is no Terraform registry module for it). For
# endpoint_type = "CloudFront", apply this in us-east-1.

locals {
  template_url = "https://solutions-reference.s3.amazonaws.com/aws-waf-security-automations/latest/aws-waf-security-automations.template"
}

resource "aws_cloudformation_stack" "waf_security_automations" {
  name         = var.stack_name
  template_url = local.template_url
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND"]

  parameters = {
    EndpointType                              = var.endpoint_type
    AppAccessLogBucket                        = var.log_bucket
    RequestThreshold                          = var.request_threshold
    ActivateHttpFloodProtectionParam          = "yes - AWS WAF rate based rule"
    ActivateScannersProbesProtectionParam     = "yes - AWS Lambda log parser"
    ActivateReputationListsProtectionParam    = "yes"
    ActivateBadBotProtectionParam             = "yes"
    ActivateSqlInjectionProtectionParam       = "yes"
    ActivateCrossSiteScriptingProtectionParam = "yes"
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "main" {
  count        = var.resource_arn != "" ? 1 : 0
  resource_arn = var.resource_arn
  web_acl_arn  = aws_cloudformation_stack.waf_security_automations.outputs["WAFWebACLArn"]
}

variable "stack_name" {
  type    = string
  default = "aws-waf-security-automations"
}

variable "endpoint_type" {
  description = "Resource type the web ACL protects: ALB or CloudFront."
  type        = string
  default     = "ALB"

  validation {
    condition     = contains(["ALB", "CloudFront"], var.endpoint_type)
    error_message = "endpoint_type must be ALB or CloudFront."
  }
}

variable "request_threshold" {
  description = "Maximum requests per 5 minutes from a single IP before it is blocked."
  type        = number
  default     = 2000
}

variable "log_bucket" {
  description = "Name of the S3 bucket that receives the application access logs."
  type        = string
}

variable "resource_arn" {
  description = "ARN of an ALB to associate with the web ACL. Leave empty to skip (CloudFront associates through the distribution)."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

output "web_acl_arn" {
  value = aws_cloudformation_stack.waf_security_automations.outputs["WAFWebACLArn"]
}
