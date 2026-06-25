variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "dns_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "prefix" {
  description = "Environment prefix (e.g. dev, prod)"
  type        = string
}

variable "backend_image_uri" {
  description = "Full Docker image URI for the backend container"
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
