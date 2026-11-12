variable "alarm_email" {
  type        = string
  description = "E-post som varsles av alarmen"
  default     = ""
}

locals {
  metrics_namespace = "whishifai-${var.candidate}"
}

resource "aws_sns_topic" "alarms" {
  name = "wishifai-alarms-${var.candidate}"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "parse_failures" {
  alarm_name          = "whishifai-parse-failures-${var.candidate}"
  alarm_description   = "Bedrock-svar som ikke kunne parses som JSON"
  namespace           = local.metrics_namespace
  metric_name         = "bedrock.parse.failures.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "wishifai-${var.candidate}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Business: gaveforslag generert"
          region = var.region
          view   = "timeSeries"
          period = 300
          stat   = "Sum"
          metrics = [
            [local.metrics_namespace, "gifts.suggested.count"]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Business: forslag per prompt (snitt)"
          region = var.region
          view   = "timeSeries"
          period = 300
          metrics = [
            [{ expression = "m1/m2", label = "Forslag per prompt", id = "e1" }],
            [local.metrics_namespace, "gifts.per.prompt.sum", { id = "m1", stat = "Sum", visible = false }],
            [local.metrics_namespace, "gifts.per.prompt.count", { id = "m2", stat = "Sum", visible = false }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "App: Bedrock gjennomsnittlig tid (ms)"
          region = var.region
          view   = "timeSeries"
          period = 300
          metrics = [
            [{ expression = "m1/m2", label = "Bedrock snitt (ms)", id = "e1" }],
            [local.metrics_namespace, "bedrock.converse.duration.sum", { id = "m1", stat = "Sum", visible = false }],
            [local.metrics_namespace, "bedrock.converse.duration.count", { id = "m2", stat = "Sum", visible = false }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "App: Rekognition gjennomsnittlig tid (ms)"
          region = var.region
          view   = "timeSeries"
          period = 300
          metrics = [
            [{ expression = "m1/m2", label = "Rekognition snitt (ms)", id = "e1" }],
            [local.metrics_namespace, "rekognition.detectlabels.duration.sum", { id = "m1", stat = "Sum", visible = false }],
            [local.metrics_namespace, "rekognition.detectlabels.duration.count", { id = "m2", stat = "Sum", visible = false }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "App (Actuator): JVM GC-overhead"
          region = var.region
          view   = "timeSeries"
          period = 300
          stat   = "Average"
          metrics = [
            [local.metrics_namespace, "jvm.gc.overhead.value"]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Infra (ECS): CPU og minne (%)"
          region = var.region
          view   = "timeSeries"
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_express_gateway_service.app.cluster, "ServiceName", aws_ecs_express_gateway_service.app.service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_express_gateway_service.app.cluster, "ServiceName", aws_ecs_express_gateway_service.app.service_name]
          ]
        }
      }
    ]
  })
}

output "dashboard_name" {
  value = "aws_cloudwatch_dashboard.main.dashboard_name"
}
