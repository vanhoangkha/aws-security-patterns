# AWS Config Custom Rules with CloudFormation Guard

resource "aws_config_config_rule" "custom_guard" {
  for_each = var.guard_rules

  name = each.key

  source {
    owner = "CUSTOM_POLICY"

    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }

    custom_policy_details {
      policy_runtime = "guard-2.x.x"
      policy_text    = each.value.policy
    }
  }

  scope {
    compliance_resource_types = each.value.resource_types
  }
}

variable "guard_rules" {
  type = map(object({
    policy         = string
    resource_types = list(string)
  }))
  default = {
    "s3-bucket-encryption" = {
      policy = <<-GUARD
        rule s3_bucket_encryption {
          resourceType == "AWS::S3::Bucket"
          configuration.ServerSideEncryptionConfiguration exists
          configuration.ServerSideEncryptionConfiguration.Rules[*].ApplyServerSideEncryptionByDefault.SSEAlgorithm == "aws:kms"
        }
      GUARD
      resource_types = ["AWS::S3::Bucket"]
    }
    "ec2-imdsv2-required" = {
      policy = <<-GUARD
        rule ec2_imdsv2_required {
          resourceType == "AWS::EC2::Instance"
          configuration.MetadataOptions.HttpTokens == "required"
        }
      GUARD
      resource_types = ["AWS::EC2::Instance"]
    }
    "rds-multi-az" = {
      policy = <<-GUARD
        rule rds_multi_az {
          resourceType == "AWS::RDS::DBInstance"
          configuration.MultiAZ == true
        }
      GUARD
      resource_types = ["AWS::RDS::DBInstance"]
    }
  }
}

# Remediation actions
resource "aws_config_remediation_configuration" "s3_encryption" {
  config_rule_name = aws_config_config_rule.custom_guard["s3-bucket-encryption"].name

  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-EnableS3BucketEncryption"
  target_version   = "1"

  parameter {
    name         = "BucketName"
    resource_value {
      value = "RESOURCE_ID"
    }
  }

  parameter {
    name         = "SSEAlgorithm"
    static_value {
      values = ["aws:kms"]
    }
  }

  automatic                  = var.auto_remediate
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

variable "auto_remediate" {
  type    = bool
  default = false
}
