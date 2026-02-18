# AWS Security Patterns

Collection of AWS security automation patterns based on [AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/securityandcompliance-pattern-list.html).

## 📁 Structure

```
├── incident-response/      # Automated incident response & forensics
├── iam-security/           # IAM policies, access analyzer, identity
├── network-security/       # WAF, Network Firewall, VPC security
├── data-protection/        # Encryption, KMS, S3 security
├── compliance/             # AWS Config, Control Tower, PCI-DSS
├── monitoring/             # GuardDuty, Security Hub, CloudWatch
├── secrets-management/     # Secrets Manager, certificate management
└── container-security/     # Container image hardening, ECR scanning
```

## 🛠️ Patterns Included

### Incident Response
- Automated incident response and forensics
- Security alerts to Slack

### IAM Security
- Centralized IAM access key management
- IAM policy validation with Access Analyzer
- Root user activity monitoring
- IAM user creation notifications
- Permission sets as code

### Network Security
- AWS WAF security automations
- Network Firewall DNS capture
- IP/Geolocation restrictions
- Public subnet access controls

### Data Protection
- RDS encryption remediation
- KMS key deletion monitoring
- S3 public bucket detection
- CloudWatch Logs protection with Macie
- ElastiCache encryption monitoring

### Compliance
- AWS Config custom rules with CloudFormation Guard
- Control Tower controls (CDK & Terraform)
- PCI DSS 4.0 validation
- Prowler consolidated reports

### Monitoring
- GuardDuty auto-enable (Terraform)
- Security Hub + Jira integration
- RDS CA certificate expiration detection
- CloudFront security checks

### Secrets Management
- AWS Secrets Manager patterns
- Private CA with AWS RAM
- Secure file transfers

### Container Security
- Hardened container image pipeline
- Git repository scanning

## 🚀 Quick Start

```bash
# Clone repo
git clone https://github.com/vanhoangkha/aws-security-patterns.git
cd aws-security-patterns

# Deploy a pattern (example: GuardDuty)
cd monitoring/guardduty-enable
terraform init
terraform plan
terraform apply
```

## 📋 Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- AWS CDK (for CDK patterns)
- Python 3.9+ (for Lambda functions)

## 📚 References

- [AWS Prescriptive Guidance - Security Patterns](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/securityandcompliance-pattern-list.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [AWS Security Hub](https://docs.aws.amazon.com/securityhub/)

## 📄 License

MIT License
