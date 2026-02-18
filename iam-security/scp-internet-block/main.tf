# Service Control Policy - Block Internet Access

resource "aws_organizations_policy" "deny_internet" {
  name        = "deny-internet-access"
  description = "Prevent internet access at account level"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInternetGateway"
        Effect    = "Deny"
        Action    = [
          "ec2:AttachInternetGateway",
          "ec2:CreateInternetGateway",
          "ec2:CreateEgressOnlyInternetGateway",
          "ec2:CreateVpcPeeringConnection",
          "ec2:AcceptVpcPeeringConnection"
        ]
        Resource  = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = var.exception_roles
          }
        }
      },
      {
        Sid       = "DenyPublicSubnet"
        Effect    = "Deny"
        Action    = [
          "ec2:CreateRoute",
          "ec2:ReplaceRoute"
        ]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "ec2:GatewayType" = "igw"
          }
          StringNotLike = {
            "aws:PrincipalArn" = var.exception_roles
          }
        }
      },
      {
        Sid       = "DenyPublicIP"
        Effect    = "Deny"
        Action    = [
          "ec2:RunInstances"
        ]
        Resource  = "arn:aws:ec2:*:*:network-interface/*"
        Condition = {
          Bool = {
            "ec2:AssociatePublicIpAddress" = "true"
          }
          StringNotLike = {
            "aws:PrincipalArn" = var.exception_roles
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_internet" {
  policy_id = aws_organizations_policy.deny_internet.id
  target_id = var.target_ou_id
}

variable "target_ou_id" {
  type        = string
  description = "OU ID to attach the SCP"
}

variable "exception_roles" {
  type    = list(string)
  default = ["arn:aws:iam::*:role/NetworkAdmin"]
}
