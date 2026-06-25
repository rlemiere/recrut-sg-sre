output "frontend_url" {
  value = "https://${local.frontend_domain}"
}

output "api_url" {
  value = "https://${local.api_domain}"
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution_id
}

output "s3_bucket_name" {
  value = module.s3_frontend.s3_bucket_id
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.name
}

output "rds_endpoint" {
  value     = module.rds.db_instance_address
  sensitive = true
}
