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
  name               = "taxflowsai-codebuild-role-v2"
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
data "aws_iam_policy_document" "artifact_bucket_access" {
  statement {
    sid     = "AllowPipelineArtifacts"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.artifact_bucket}",
      "arn:aws:s3:::${var.artifact_bucket}/*",
    ]
  }
}

data "aws_iam_policy_document" "codestar_connection" {
  statement {
    sid       = "AllowUseOfCodeStarConnection"
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.codestar_connection_arn]
  }
}

data "aws_iam_policy_document" "pipeline_start_build" {
  statement {
    sid    = "AllowPipelineStartBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
      "codebuild:BatchGetProjects",
    ]
    resources = [
      aws_codebuild_project.terraform_build.arn,
      aws_codebuild_project.terraform_plan.arn,
      aws_codebuild_project.terraform_apply.arn,
    ]
  }
}

locals {
  codebuild_logs_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudWatchLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  }
}

resource "aws_iam_policy" "artifact_bucket_access" {
  name        = "taxflowsai-artifact-bucket-access"
  description = "Allow CI/CD to read/write S3 artifacts"
  policy      = data.aws_iam_policy_document.artifact_bucket_access.json
  tags = {
    Env     = "prod"
    Project = "TaxFlowsAI"
  }
}

resource "aws_iam_policy" "codestar_connection" {
  name        = "taxflowsai-codestar-connection"
  description = "Allow use of CodeStar connection"
  policy      = data.aws_iam_policy_document.codestar_connection.json
  tags = {
    Env     = "prod"
    Project = "TaxFlowsAI"
  }
}

resource "aws_iam_policy" "pipeline_start_build" {
  name        = "taxflowsai-pipeline-start-build"
  description = "Allow pipeline to start CodeBuild projects"
  policy      = data.aws_iam_policy_document.pipeline_start_build.json
  tags = {
    Env     = "prod"
    Project = "TaxFlowsAI"
  }
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
  policy_arn = aws_iam_policy.artifact_bucket_access.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_artifacts" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.artifact_bucket_access.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_codestar" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codestar_connection.arn
}

resource "aws_iam_role_policy_attachment" "codepipeline_start_build" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.pipeline_start_build.arn
}

resource "aws_iam_role_policy" "codebuild_logs" {
  name   = "codebuild-logs-policy"
  role   = aws_iam_role.codebuild.id
  policy = jsonencode(local.codebuild_logs_policy)
}

# ──────────────────────────────────────────────────────────────────────────────
# 5) Artifact S3 Bucket
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket
  tags = {
    Environment = "prod"
    Project     = "TaxFlowsAI"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# 6) CodeBuild Projects
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_codebuild_project" "terraform_build" {
  name         = "taxflowsai-terraform-build"
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
    buildspec = "terraform/buildspec-tf-build.yml"
  }

  tags = { Project = "TaxFlowsAI", Environment = "prod" }
}

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
    location = aws_s3_bucket.artifacts.bucket
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
    name = "Build"
    action {
      name             = "PrepareDependencies"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
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
      input_artifacts  = ["BuildOutput"]
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
