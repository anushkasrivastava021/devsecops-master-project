# 1. Define the Required Providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

# 2. Provision the S3 Artifact Store
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "devsecops-pipeline-artifacts-2026"
  force_destroy = true 
}

# 3. Secure the Bucket (DevSecOps Best Practice)
resource "aws_s3_bucket_public_access_block" "secure_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Define the IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-2026"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# 5. Define the Permissions Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-policy-2026"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# 6. Provision the AWS CodeBuild Project
resource "aws_codebuild_project" "app_build" {
  name          = "server-monitor-build-2026"
  description   = "Builds the Docker image and prepares deployment artifacts"
  build_timeout = "15" 
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Required for Docker commands
  }

  source {
    type = "CODEPIPELINE"
  }
}

# ==========================================
# PHASE 4 & 5: EC2 TARGET & CODEDEPLOY
# ==========================================

# 7. IAM Role & Profile for the EC2 Server
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-2026"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "ec2-s3-policy-2026"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Action = ["s3:Get*", "s3:List*"],
      Resource = [aws_s3_bucket.pipeline_artifacts.arn, "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-2026"
  role = aws_iam_role.ec2_role.name
}

# 8. Provision the Target EC2 Server
resource "aws_instance" "app_server" {
  ami                  = "ami-0c101f26f147fa7fd" # Amazon Linux 2023 in us-east-1
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Environment = "Production"
  }

  # Install CodeDeploy Agent automatically on boot
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y ruby wget
              cd /home/ec2-user
              wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
              chmod +x ./install
              ./install auto
              systemctl start codedeploy-agent
              EOF
}

# 9. IAM Role for CodeDeploy Service
resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-role-2026"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codedeploy.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# 10. Create the CodeDeploy App and Deployment Group
resource "aws_codedeploy_app" "app" {
  name             = "server-monitor-app-2026"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "deploy_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "server-monitor-group-2026"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  # This tells CodeDeploy exactly which servers to update
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = "Production"
    }
  }
}

# ==========================================
# PHASE 6: AWS CODEPIPELINE (THE ORCHESTRATOR)
# ==========================================

# 11. IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-2026"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" } }]
  })
}

# 12. Policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy-2026"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow", Action = ["s3:*"],
        Resource = [aws_s3_bucket.pipeline_artifacts.arn, "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect = "Allow", Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"],
        Resource = aws_codebuild_project.app_build.arn
      },
      {
        Effect = "Allow",
        Action = ["codedeploy:CreateDeployment", "codedeploy:GetDeployment", "codedeploy:GetDeploymentConfig", "codedeploy:RegisterApplicationRevision"],
        Resource = "*"
      },
      {
        Effect = "Allow", Action = ["codestar-connections:UseConnection"],
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

# 13. The CodeStar Connection (The Handshake)
resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection-2026"
  provider_type = "GitHub"
}

# 14. The Pipeline Orchestrator
resource "aws_codepipeline" "main_pipeline" {
  name     = "server-monitor-pipeline-2026"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # STAGE 1: Pull code from GitHub
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "anushkasrivastava021/devsecops-master-project"
        BranchName       = "main"
      }
    }
  }

  # STAGE 2: Send code to CodeBuild
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  # STAGE 3: Send compiled artifact to CodeDeploy & EC2
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.deploy_group.deployment_group_name
      }
    }
  }
}