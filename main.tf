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

data "aws_s3_bucket" "artifacts" {
  bucket = "dotnet-bluegreen-artifacts-demo-604604739963"
}

data "aws_lb_target_group" "blue" {
  name = "blue-tg-demo"
}

data "aws_lb_target_group" "green" {
  name = "green-tg-demo"
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

resource "aws_launch_template" "app" {

  name_prefix   = "dotnet-template"
  image_id      = "ami-03bb6d83c60fc5f7c"
  instance_type = "t2.micro"

  vpc_security_group_ids = [
    data.aws_security_group.ec2_sg.id
  ]

  user_data = base64encode(<<EOF
#!/bin/bash
apt update -y
apt install -y ruby wget
cd /home/ubuntu
wget https://aws-codedeploy-ap-south-1.s3.amazonaws.com/latest/install
chmod +x install
./install auto
service codedeploy-agent start
EOF
)
}

resource "aws_autoscaling_group" "blue" {

  desired_capacity = 1
  min_size         = 1
  max_size         = 1

  vpc_zone_identifier = [
    data.aws_subnet.subnet1.id
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [
    data.aws_lb_target_group.blue.arn
  ]
}

resource "aws_autoscaling_group" "green" {

  desired_capacity = 1
  min_size         = 1
  max_size         = 1

  vpc_zone_identifier = [
    data.aws_subnet.subnet2.id
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [
    data.aws_lb_target_group.green.arn
  ]
}

resource "aws_codedeploy_app" "app" {
  name = "dotnet-bluegreen-demo"
}

resource "aws_codedeploy_deployment_group" "group" {

  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "bluegreen-group"

  service_role_arn = data.aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [
    aws_autoscaling_group.blue.name
  ]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_info {
      name = data.aws_lb_target_group.blue.name
    }
  }
}

resource "aws_codebuild_project" "build" {

  name         = "dotnet-build"
  service_role = data.aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {

    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type = "CODEPIPELINE"
  }
}

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

      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeStarSourceConnection"
      version  = "1"

      output_artifacts = ["source_output"]

      configuration = {

        ConnectionArn    = "arn:aws:codeconnections:ap-south-1:604604739963:connection/fe390ed6-8294-4547-bc45-6f57f1ce0c4d"
        FullRepositoryId = "Sids-Repo/dotnet-bluegreen-demo"
        BranchName       = "main"
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

        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.group.deployment_group_name
      }
    }
  }
}
