output "bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "service_url" {
  value = aws_ecs_express_gateway_service.app.ingress_paths[0].endpoint
}

