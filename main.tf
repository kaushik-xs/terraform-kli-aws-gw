resource "aws_api_gateway_rest_api" "default" {
  name = var.NAME
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.default.body,
      aws_api_gateway_method.default.id,
      aws_api_gateway_integration.default.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "default" {
  deployment_id = aws_api_gateway_deployment.default.id
  rest_api_id   = aws_api_gateway_rest_api.default.id
  stage_name    = "prod"
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      deployment_id
    ]
  }
  depends_on = [
    aws_api_gateway_method.default,
    aws_api_gateway_method_response.default
  ]
}

resource "aws_api_gateway_usage_plan" "default" {
  count       = length(var.USAGE_PLANS)
  name        = var.USAGE_PLANS[count.index].name
  description = var.USAGE_PLANS[count.index].description

  api_stages {
    api_id = aws_api_gateway_rest_api.default.id
    stage  = aws_api_gateway_stage.default.stage_name
  }

  quota_settings {
    limit  = var.USAGE_PLANS[count.index].quota_settings.limit
    offset = var.USAGE_PLANS[count.index].quota_settings.offset
    period = var.USAGE_PLANS[count.index].quota_settings.period
  }

  throttle_settings {
    burst_limit = var.USAGE_PLANS[count.index].throttle_settings.burst_limit
    rate_limit  = var.USAGE_PLANS[count.index].throttle_settings.rate_limit
  }


}

resource "aws_acm_certificate" "default" {
  domain_name       = var.DOMAIN_NAME
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "default" {
  for_each = {
    for dvo in aws_acm_certificate.default.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.AWS_ROUTE53_ZONE_ID
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn         = aws_acm_certificate.default.arn
  validation_record_fqdns = [for record in aws_route53_record.default : record.fqdn]
}



resource "aws_api_gateway_domain_name" "default" {
  domain_name              = var.DOMAIN_NAME
  regional_certificate_arn = aws_acm_certificate_validation.default.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "api_record" {
  name    = aws_api_gateway_domain_name.default.domain_name
  type    = "A"
  zone_id = var.AWS_ROUTE53_ZONE_ID

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.default.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.default.regional_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "default" {
  api_id      = aws_api_gateway_rest_api.default.id
  stage_name  = aws_api_gateway_stage.default.stage_name
  domain_name = aws_api_gateway_domain_name.default.domain_name
}

# Rest gateway Resource creation
# Meta Resource
resource "aws_api_gateway_resource" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_rest_api.default.root_resource_id
  path_part   = "meta"
}

resource "aws_api_gateway_method" "default" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.default.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.default.id
  http_method = aws_api_gateway_method.default.http_method
  type        = "MOCK"
}

resource "aws_api_gateway_method_response" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  resource_id = aws_api_gateway_resource.default.id
  http_method = aws_api_gateway_method.default.http_method
  status_code = "200"
}
