variable "NAME" {
  description = "Name of the AWS Rest Gateway"
}
variable "DOMAIN_NAME" {
  description = "Domain name to which the Rest Gateway should be mapped to"
}

variable "AWS_ROUTE53_ZONE_ID" {
  description = "Route53 Zone ID"
}

variable "USAGE_PLANS" {
  type = list(object({
    name = string
    description = string
    quota_settings = object({
      limit = number
      offset = number
      period = string
    })
    throttle_settings = object({
      burst_limit = number
      rate_limit = number
    })
  }))
  description = "Add usage plans"
}