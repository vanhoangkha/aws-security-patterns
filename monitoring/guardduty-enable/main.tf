# GuardDuty Auto-Enable for Organization

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_guardduty_organization_admin_account" "main" {
  count            = var.is_organization_admin ? 1 : 0
  admin_account_id = var.admin_account_id
}

resource "aws_guardduty_organization_configuration" "main" {
  count       = var.is_organization_admin ? 1 : 0
  detector_id = aws_guardduty_detector.main.id
  auto_enable_organization_members = "ALL"

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }
}

variable "is_organization_admin" {
  type    = bool
  default = false
}

variable "admin_account_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {
    Environment = "security"
    ManagedBy   = "terraform"
  }
}

output "detector_id" {
  value = aws_guardduty_detector.main.id
}
