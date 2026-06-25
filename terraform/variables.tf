variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "dns_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "prefix" {
  description = "Prefix for AWS resource names (e.g. urlshortener-dev)"
  type        = string
}

variable "dns_prefix" {
  description = "DNS subdomain prefix (e.g. dev -> dev.example.com)"
  type        = string
}

variable "backend_repository" {
  description = "Docker image repository for the backend container (without tag)"
  type        = string
}

variable "backend_version" {
  description = "Docker image tag to deploy (e.g. git SHA)"
  type        = string
}

variable "backend_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "backend_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "backend_desired_count" {
  description = "Initial ECS task count"
  type        = number
  default     = 1
}

variable "backend_min_capacity" {
  description = "Autoscaling minimum task count"
  type        = number
  default     = 1
}

variable "backend_max_capacity" {
  description = "Autoscaling maximum task count"
  type        = number
  default     = 4
}

variable "frontend_version" {
  description = "Identifier used to trigger S3 sync and CloudFront invalidation (e.g. git SHA)"
  type        = string
  default     = ""
}

variable "frontend_dist_dir" {
  description = "Path to the frontend dist folder, relative to the terraform directory"
  type        = string
  default     = "../frontend/dist"
}
