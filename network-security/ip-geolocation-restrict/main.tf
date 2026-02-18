# IP/Geolocation Restriction with WAF

resource "aws_wafv2_ip_set" "blocked" {
  name               = "blocked-ips"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.blocked_ips
}

resource "aws_wafv2_ip_set" "allowed" {
  name               = "allowed-ips"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ips
}

resource "aws_wafv2_web_acl" "main" {
  name  = "geo-ip-restriction"
  scope = var.scope

  default_action {
    allow {}
  }

  # Block specific IPs
  rule {
    name     = "block-ips"
    priority = 1

    override_action {
      none {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked.arn
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockedIPs"
      sampled_requests_enabled   = true
    }
  }

  # Block countries
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "block-countries"
      priority = 2

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      action {
        block {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockedCountries"
        sampled_requests_enabled   = true
      }
    }
  }

  # Allow only specific countries
  dynamic "rule" {
    for_each = length(var.allowed_countries) > 0 ? [1] : []
    content {
      name     = "allow-countries-only"
      priority = 3

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.allowed_countries
            }
          }
        }
      }

      action {
        block {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AllowedCountriesOnly"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "GeoIPRestriction"
    sampled_requests_enabled   = true
  }
}

variable "scope" {
  type    = string
  default = "REGIONAL"
}

variable "blocked_ips" {
  type    = list(string)
  default = []
}

variable "allowed_ips" {
  type    = list(string)
  default = []
}

variable "blocked_countries" {
  type    = list(string)
  default = []
}

variable "allowed_countries" {
  type    = list(string)
  default = []
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}
