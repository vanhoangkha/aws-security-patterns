# IAM Access Analyzer Policy Validation Pipeline

resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "iam-policy-analyzer"
  type          = var.analyzer_type
}

resource "aws_codepipeline" "iam_validation" {
  name     = "iam-policy-validation"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = var.repository_name
        BranchName     = var.branch_name
      }
    }
  }

  stage {
    name = "Validate"
    action {
      name             = "ValidatePolicies"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["validate_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.validate.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployPolicies"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ActionMode    = "CREATE_UPDATE"
        StackName     = "iam-policies"
        TemplatePath  = "source_output::iam-policies.yaml"
        RoleArn       = aws_iam_role.cloudformation.arn
        Capabilities  = "CAPABILITY_NAMED_IAM"
      }
    }
  }
}

resource "aws_codebuild_project" "validate" {
  name         = "iam-policy-validator"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          commands:
            - pip install boto3
        build:
          commands:
            - |
              python3 << 'EOF'
              import boto3
              import json
              import glob
              import sys

              analyzer = boto3.client('accessanalyzer')
              errors = []

              for policy_file in glob.glob('policies/*.json'):
                  with open(policy_file) as f:
                      policy = json.load(f)
                  
                  response = analyzer.validate_policy(
                      policyDocument=json.dumps(policy),
                      policyType='IDENTITY_POLICY'
                  )
                  
                  for finding in response.get('findings', []):
                      if finding['findingType'] in ['ERROR', 'SECURITY_WARNING']:
                          errors.append({
                              'file': policy_file,
                              'type': finding['findingType'],
                              'message': finding['findingDetails']
                          })

              if errors:
                  print("Policy validation failed:")
                  for e in errors:
                      print(f"  {e['file']}: [{e['type']}] {e['message']}")
                  sys.exit(1)
              
              print("All policies validated successfully")
              EOF
    BUILDSPEC
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "iam-pipeline-artifacts-"
}

resource "aws_iam_role" "codepipeline" {
  name = "iam-validation-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role" "codebuild" {
  name = "iam-validator-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "access-analyzer"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["access-analyzer:ValidatePolicy"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "cloudformation" {
  name = "iam-deployment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "cloudformation.amazonaws.com" }
    }]
  })
}

variable "analyzer_type" {
  type    = string
  default = "ACCOUNT"
}

variable "repository_name" {
  type = string
}

variable "branch_name" {
  type    = string
  default = "main"
}
