# Control Tower Controls with Terraform

resource "aws_controltower_control" "controls" {
  for_each = toset(var.control_identifiers)

  control_identifier = each.value
  target_identifier  = var.organizational_unit_arn
}

variable "organizational_unit_arn" {
  type        = string
  description = "ARN of the OU to apply controls"
}

variable "control_identifiers" {
  type = list(string)
  default = [
    # Data residency
    "arn:aws:controltower:us-east-1::control/AWS-GR_REGION_DENY",
    
    # Encryption
    "arn:aws:controltower:us-east-1::control/AWS-GR_EBS_OPTIMIZED_INSTANCE",
    "arn:aws:controltower:us-east-1::control/AWS-GR_ENCRYPTED_VOLUMES",
    "arn:aws:controltower:us-east-1::control/AWS-GR_RDS_INSTANCE_PUBLIC_ACCESS_CHECK",
    "arn:aws:controltower:us-east-1::control/AWS-GR_RDS_STORAGE_ENCRYPTED",
    "arn:aws:controltower:us-east-1::control/AWS-GR_S3_BUCKET_PUBLIC_READ_PROHIBITED",
    "arn:aws:controltower:us-east-1::control/AWS-GR_S3_BUCKET_PUBLIC_WRITE_PROHIBITED",
    
    # Logging
    "arn:aws:controltower:us-east-1::control/AWS-GR_CLOUDTRAIL_ENABLED",
    "arn:aws:controltower:us-east-1::control/AWS-GR_CLOUDTRAIL_VALIDATION_ENABLED",
    
    # Network
    "arn:aws:controltower:us-east-1::control/AWS-GR_RESTRICTED_SSH",
    "arn:aws:controltower:us-east-1::control/AWS-GR_RESTRICTED_COMMON_PORTS",
    "arn:aws:controltower:us-east-1::control/AWS-GR_VPC_FLOW_LOGS_ENABLED",
    
    # IAM
    "arn:aws:controltower:us-east-1::control/AWS-GR_IAM_USER_MFA_ENABLED",
    "arn:aws:controltower:us-east-1::control/AWS-GR_ROOT_ACCOUNT_MFA_ENABLED",
    "arn:aws:controltower:us-east-1::control/AWS-GR_IAM_USER_UNUSED_CREDENTIALS_CHECK"
  ]
}

output "enabled_controls" {
  value = [for c in aws_controltower_control.controls : c.control_identifier]
}
