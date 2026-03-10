resource "aws_codepipeline" "pipeline" {

  name     = "dotnet-bluegreen-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {

    location = aws_s3_bucket.artifacts.bucket
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

        ConnectionArn    = "arn:aws:codeconnections:ap-south-1:604604739963:connection/e06a73b1-09cd-48d2-ae59-99a33c526c28"
        FullRepositoryId = "Sids-Repo/dotnet-bluegreen-demo"
        BranchName       = "main"
        DetectChanges    = "true"
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
