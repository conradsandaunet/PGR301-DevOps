terraform {
  backend "s3" {
    bucket  = "pgr301-terraform-state"
    key     = "wishifai/26/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }

  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.23.0" }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "images" {
  bucket        = "wishifai-${var.candidate}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "wishifai-task-${var.candidate}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    sid       = "UploadedImages"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.images.arn}/uploads/*"]
  }

  statement {
    sid       = "DetectLabels"
    actions   = ["rekognition:DetectLabels"]
    resources = ["*"]
  }

  statement {
    sid     = "InvokeModel"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}",
      "arn:aws:bedrock:*::foundation-model/${trimprefix(var.bedrock_model_id, "eu.")}",
    ]
  }

  statement {
    sid       = "PutMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = ["wishifai-${var.candidate}"]
      variable = "cloudwatch:namespace"
    }
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "wishifai-task-policy-${var.candidate}"
  policy = data.aws_iam_policy_document.task_permissions.json
  role   = aws_iam_role.task.id
}

resource "aws_ecs_express_gateway_service" "app" {
  service_name            = "wishifai-${var.candidate}"
  execution_role_arn      = "arn:aws:iam::244530008913:role/ecsTaskExecutionRole"
  infrastructure_role_arn = "arn:aws:iam::244530008913:role/service-role/ecsInfrastructureRoleForExpressServices"
  task_role_arn           = aws_iam_role.task.arn
  health_check_path       = "/actuator/health"

  primary_container {
    image          = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/wishifai:${var.image_tag}"
    container_port = 8080

    environment {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.images.bucket
    }

    environment {
      name  = "AWS_REGION"
      value = var.region
    }

    environment {
      name  = "BEDROCK_MODEL_ID"
      value = var.bedrock_model_id
    }
  }

  depends_on = [aws_iam_role_policy.task]
}