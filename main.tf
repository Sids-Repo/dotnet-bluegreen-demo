provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "existing" {
  id = "vpc-0e063acc05d699fe8"
}

data "aws_subnet" "subnet1" {
  id = "subnet-04c8f806e7d7bfbee"
}

data "aws_subnet" "subnet2" {
  id = "subnet-0751f308f8f14bfa8"
}

data "aws_security_group" "ec2_sg" {
  id = "sg-0b10b757a7c7395b9"
}

data "aws_lb_target_group" "blue" {
  name = "blue-tg-demo"
}

data "aws_lb_target_group" "green" {
  name = "green-tg-demo"
}

data "aws_s3_bucket" "artifacts" {
  bucket = "dotnet-bluegreen-artifacts-demo-604604739963"
}

data "aws_iam_role" "pipeline_role" {
  name = "pipeline-role-demo"
}

data "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-demo"
}

data "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-role-demo"
}

########################################
# EC2 ROLE FOR CODEDEPLOY
########################################

resource "aws_iam_role" "ec2_role" {
  name = "codedeploy-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_ec2_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "codedeploy-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

########################################
# LAUNCH TEMPLATE
########################################

resource "aws_launch_template" "app" {

  name_prefix   = "dotnet-template"
  image_id      = "ami-03bb6d83c60fc5f7c"
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [data.aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash

set -e

apt-get update -y
apt-get install -y ruby wget

cd /home/ubuntu

wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install

chmod +x install

./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent

sleep 20

systemctl restart codedeploy-agent

EOF
  )
}

########################################
# CODEDEPLOY APPLICATION
########################################

resource "aws_codedeploy_app" "app" {

  name             = "dotnet-bluegreen-demo"
  compute_platform = "Server"
}

########################################
# CODEDEPLOY DEPLOYMENT GROUP
########################################

resource "aws_codedeploy_deployment_group" "group" {

  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "bluegreen-group"

  service_role_arn = data.aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [
    "terraform-20260307154006365400000006"
  ]

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {

      action = "TERMINATE"

      termination_wait_time_in_minutes = 5
    }
  }

  load_balancer_info {

    target_group_info {
      name = data.aws_lb_target_group.blue.name
    }
  }
}

########################################
# CODEBUILD PROJECT
########################################

resource "aws_codebuild_project" "build" {

  name         = "dotnet-build"
  service_role = data.aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {

    compute_type = "BUILD_GENERAL1_SMALL"

    image = "aws/codebuild/standard:7.0"

    type = "LINUX_CONTAINER"
  }

  source {
    type = "CODEPIPELINE"
  }
}

########################################
# CODEPIPELINE
########################################

resource "aws_codepipeline" "pipeline" {

  name     = "dotnet-bluegreen-pipeline"
  role_arn = data.aws_iam_role.pipeline_role.arn

  artifact_store {

    location = data.aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

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

        ConnectionArn = "arn:aws:codeconnections:ap-south-1:604604739963:connection/e06a73b1-09cd-48d2-ae59-99a33c526c28"

        FullRepositoryId = "Sids-Repo/dotnet-bluegreen-demo"

        BranchName = "main"

        DetectChanges = "true"
      }
    }
  }

  stage {

    name = "Build"

    action {

      name     = "Build"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"

      input_artifacts  = ["source_output"]

      output_artifacts = ["build_output"]

      configuration = {

        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {

    name = "Deploy"

    action {

      name     = "Deploy"
      category = "Deploy"
      owner    = "AWS"
      provider = "CodeDeploy"
      version  = "1"

      input_artifacts = ["build_output"]

      configuration = {

        ApplicationName = aws_codedeploy_app.app.name

        DeploymentGroupName = aws_codedeploy_deployment_group.group.deployment_group_name
      }
    }
  }
}
