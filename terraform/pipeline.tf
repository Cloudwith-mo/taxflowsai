# ──────────────────────────────────────────────────────────────────────────────
# 1) IAM Policy Documents for AssumeRole
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    sid     = "AllowCodeBuildServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    sid     = "AllowCodePipelineServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# 2) IAM Roles
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "codebuild" {
  name               = "taxflowsai-codebuild-role-v3"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags = {
    Project = "TaxFlowsAI"
    Env     = "prod"
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "taxflowsai-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags = {
    Project = "TaxFlowsAI"
    Env     = "prod"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# 3) Custom IAM Policies via Locals
# ──────────────────────────────────────────────────────────────────────────────
locals {
  artifact_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowPipelineArtifacts"
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.artifact_bucket}",
        "arn:aws:s3:::${var.artifact_bucket}/*",
      ]
    }]
  }

  codestar_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowUseOfCodeStarConnection"
      Effect   = "Allow"
      Action   = ["codestar-connections:UseConnection"]
      Resource = [var.codestar_connection_arn]
    }]
  }

  pipeline_start_build_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowPipelineStartBuild"
      Effect = "Allow"
      Action = [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds",
        "codebuild:BatchGetProjects",
      ]
      Resource = [
        aws_codebuild_project.terraform_plan.arn,
        aws_codebuild_project.terraform_apply.arn,
      ]
    }]
  }
}

data "aws_iam_policy" "artifact_bucket_access" {
  name = "taxflowsai-artifact-bucket-access"
}

data "aws_iam_policy" "codestar_connection" {
  name = "taxflowsai-codestar-connection"
}

data "aws_iam_policy" "pipeline_start_build" {
  name = "taxflowsai-pipeline-start-build"
}

# ──────────────────────────────────────────────────────────────────────────────
# 4) Attach Policies to Roles
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "codebuild_managed" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_managed" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_artifacts" {
  role       = aws_iam_role.codebuild.name
  policy_arn = data.aws_iam_policy.artifact_bucket_access.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_artifacts" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = data.aws_iam_policy.artifact_bucket_access.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestar" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = data.aws_iam_policy.codestar_connection.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_start_build" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = data.aws_iam_policy.pipeline_start_build.arn
}

# ──────────────────────────────────────────────────────────────────────────────
# 5) Artifact S3 Bucket
# ──────────────────────────────────────────────────────────────────────────────
data "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket
}

# ──────────────────────────────────────────────────────────────────────────────
# 6) CodeBuild Projects
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_codebuild_project" "terraform_plan" {
  name         = "taxflowsai-terraform-plan"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "terraform/buildspec-tf-plan.yml"
  }

  tags = { Project = "TaxFlowsAI", Environment = "prod" }
}

resource "aws_codebuild_project" "terraform_apply" {
  name         = "taxflowsai-terraform-apply"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:6.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "terraform/buildspec-tf-apply.yml"
  }

  tags = { Project = "TaxFlowsAI", Environment = "prod" }
}

# ──────────────────────────────────────────────────────────────────────────────
# 7) CodePipeline Definition
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_codepipeline" "terraform" {
  name     = "taxflowsai-terraform-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type     = "S3"
    location = data.aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "FetchFromGitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      run_order        = 1

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.repository
        BranchName       = var.branch
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
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name      = "ManualApproval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
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
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }

  tags = { Project = "TaxFlowsAI", Environment = "prod" }
}
