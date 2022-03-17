output "REST_API_ROOT_ID" {
  value       = aws_api_gateway_rest_api.default.root_resource_id
  description = "REST API Gateway root resouce ID"
  sensitive   = true
}

output "REST_API_ID" {
  value       = aws_api_gateway_rest_api.default.id
  description = "REST API Gateway ID"
  sensitive   = true
}
