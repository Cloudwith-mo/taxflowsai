provider "aws" {
  region = var.region
}



# pipeline.tf

# Allow CodeBuild to assume this role
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    sid       = "AllowCodeBuildServiceAssumeRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

#######
# 2) IAM Role for CodePipeline
#######
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "TaxFlowsAI_CodePipelineRole"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
}

resource "aws_iam_role_policy" "allow_codestar_connection" {
  name = "AllowUseOfCodeStarConnection"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [
          # old style, in case any stray references still use it
          "arn:aws:codestar-connections:us-east-1:995805900737:connection/d4fb2c63-7542-4638-9226-e2cee5e764ec",
          # the new prefix that your console actually shows
          "arn:aws:codeconnections:us-east-1:995805900737:connection/d4fb2c63-7542-4638-9226-e2cee5e764ec",
        ]
      },
    ]
  })
}




# Attach AWS-managed policy for CodePipeline to access CodeCommit, CodeBuild, S3, etc.
resource "aws_iam_role_policy_attachment" "codepipeline_managed" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

#######
# 3) S3 bucket for pipeline artifacts
#######
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket
  
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

#######
# 4) CodeBuild project: terraform-plan
#######
resource "aws_iam_role" "codebuild_role" {
  name               = "TaxFlowsAI_CodeBuildRole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_caller_identity" "me" {}

resource "aws_iam_role_policy" "allow_codebuild_to_write_logs" {
  name = "AllowCodeBuildLogWrites"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.me.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.terraform_plan.name}:*"
      }
    ]
  })
}


data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Give CodeBuild permissions to read/write state, S3 and assume roles
resource "aws_iam_role_policy_attachment" "codebuild_managed" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_codebuild_project" "terraform_plan" {
  name          = "TaxFlowsAI-Terraform-Plan"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {                      # output the .tfplan
    type = "CODEPIPELINE"
  }

   environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true  # Required for docker CLI usage
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec-tf-plan.yml")
  }
}

#######
# 5) CodeBuild project: terraform-apply
#######
resource "aws_codebuild_project" "terraform_apply" {
  name          = "TaxFlowsAI-Terraform-Apply"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec-tf-apply.yml")
  }
}

#######
# 6) CodePipeline wiring
#######
resource "aws_codepipeline" "terraform" {
  name     = "TaxFlowsAI-Terraform-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  

 stage {
    name = "Source"

    action {
      name             = "FetchFromGitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      run_order        = 1
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:us-east-1:995805900737:connection/d4fb2c63-7542-4638-9226-e2cee5e764ec"
        FullRepositoryId = "Cloudwith-mo/taxflowsai"
        BranchName       = "main"
        DetectChanges    = "true"
      }

  }
}


  stage {
    name = "Plan"
    action {
      name             = "TerraformPlan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["PlanOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
      }
      run_order = 1
    }
  }

  # Manual approval before apply
  stage {
    name = "Approval"
    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      run_order = 1
    }
  }

  stage {
    name = "Apply"
    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["PlanOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
      run_order = 1
    }
  }
}

resource "aws_iam_role_policy" "allow_pipeline_s3_artifacts" {
  name = "AllowPipelineS3Artifacts"
  role = aws_iam_role.codepipeline_role.name  # or .id, depending on your setup

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
        ]
        Resource = [
          # bucket itself for list/get-bucket-location
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737",
          # all objects under your pipeline prefix
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737/TaxFlowsAI-Terraform/SourceOutp/*",
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737/TaxFlowsAI-Terraform/PlanOutput/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "allow_pipeline_codebuild" {
  name = "AllowPipelineStartBuild"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",    # optional but useful
          "codebuild:BatchGetProjects"   # optional
        ]
        Resource = [
          "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:project/TaxFlowsAI-Terraform-Plan",
          "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:project/TaxFlowsAI-Terraform-Apply",
        ]
      },
    ]
  })
}

data "aws_caller_identity" "current" {}


resource "aws_iam_role_policy_attachment" "codebuild_dev_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}


resource "aws_iam_role_policy" "allow_pipeline_to_start_build" {
  name = "AllowCodePipelineStartBuild"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:BatchGetProjects"
        ]
        Resource = aws_codebuild_project.terraform_plan.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_artifact_access" {
  name = "AllowPipelineArtifactRead"                       # Policy name
  role = aws_iam_role.TaxFlowsAI_CodeBuildRole.name        # Attach to the existing CodeBuild role
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReadFromPipelineArtifactBucket",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketLocation"
        ],
        Resource = [
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737",      # the bucket itself (for bucket-level actions)
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737/*"    # all objects within the bucket (for object-level actions)
        ]
      }
    ]
  })
}

resource "aws_iam_role" "TaxFlowsAI_CodeBuildRole" {
  name               = "TaxFlowsAI_CodeBuildRole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
  # (other role settings or attachments)
}

# 1) Create the policy
resource "aws_iam_policy" "artifact_bucket_access" {
  name        = "TaxFlowsAI_ArtifactBucketAccess"
  description = "Allow CodeBuild/CodePipeline to read/write artifacts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGetPut"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737",                    # bucket itself
          "arn:aws:s3:::taxflowsai-pipeline-artifacts-0737/*"                 # all objects
        ]
      }
    ]
  })
}

# 2) Attach it to the CodeBuild role
resource "aws_iam_role_policy_attachment" "attach_artifacts_to_codebuild" {
  role       = aws_iam_role.TaxFlowsAI_CodeBuildRole.name
  policy_arn = aws_iam_policy.artifact_bucket_access.arn
}

# 3) (If needed) Attach it also to the CodePipeline role
resource "aws_iam_role_policy_attachment" "attach_artifacts_to_codepipeline" {
  role       = aws_iam_role.codepipeline_role.name 
  policy_arn = aws_iam_policy.artifact_bucket_access.arn
}
