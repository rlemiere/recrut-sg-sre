# ─── Security Groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name   = "${var.prefix}-alb-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "ecs" {
  name   = "${var.prefix}-ecs-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "rds" {
  name   = "${var.prefix}-rds-sg"
  vpc_id = module.vpc.vpc_id
}

# ALB: accept HTTP from internet (redirected to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# ALB: accept HTTPS from internet (CloudFront + direct access)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ALB: forward to ECS on port 8000
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}

# ECS: accept from ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}

# ECS: reach public registries / CloudWatch / SSM via internet
resource "aws_vpc_security_group_egress_rule" "ecs_to_internet" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ECS: reach RDS
resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# RDS: accept from ECS
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# ─── ALB ───────────────────────────────────────────────────────────────────────

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  name     = "${var.prefix}-alb"
  vpc_id   = module.vpc.vpc_id
  subnets  = module.vpc.public_subnets
  internal = false

  security_groups = [aws_security_group.alb.id]

  target_groups = {
    backend = {
      protocol          = "HTTP"
      port              = 8000
      target_type       = "ip"
      create_attachment = false
      health_check = {
        enabled             = true
        path                = "/docs"
        protocol            = "HTTP"
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 5
        matcher             = "200"
      }
    }
  }

  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
      certificate_arn = module.acm_regional.acm_certificate_arn
      forward         = { target_group_key = "backend" }
    }
    http = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# ─── ECS Cluster ───────────────────────────────────────────────────────────────

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = "${var.prefix}-cluster"

  cluster_capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy = {
    fargate = {
      name   = "FARGATE"
      weight = 100
      base   = 1
    }
  }
}

# ─── SSM ───────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.prefix}/db_password"
  type  = "SecureString"
  value = random_password.db_password.result
}

# ─── ECS Service ───────────────────────────────────────────────────────────────

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name        = "${var.prefix}-backend"
  cluster_arn = module.ecs_cluster.arn

  cpu    = var.backend_cpu
  memory = var.backend_memory

  desired_count                     = var.backend_desired_count
  health_check_grace_period_seconds = 120

  capacity_provider_strategy = {
    fargate = {
      capacity_provider = "FARGATE"
      weight            = 100
      base              = 1
    }
  }

  create_security_group = false
  security_group_ids    = [aws_security_group.ecs.id]
  subnet_ids            = module.vpc.public_subnets
  assign_public_ip      = true

  task_exec_ssm_param_arns = [aws_ssm_parameter.db_password.arn]

  container_definitions = {
    backend = {
      image     = "${var.backend_repository}:${var.backend_version}"
      essential = true

      portMappings = [{
        containerPort = 8000
        protocol      = "tcp"
      }]

      environment = [
        { name = "DB_HOST", value = module.rds.db_instance_address },
        { name = "DB_PORT", value = tostring(module.rds.db_instance_port) },
        { name = "DB_USERNAME", value = "urlshortener" },
        { name = "DB_NAME", value = "urlshortener" },
        { name = "CORS_ORIGINS", value = "https://${local.frontend_domain}" },
      ]

      secrets = [{
        name      = "DB_PASSWORD"
        valueFrom = aws_ssm_parameter.db_password.arn
      }]

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_retention_in_days = 14
    }
  }

  load_balancer = {
    backend = {
      target_group_arn = module.alb.target_groups["backend"].arn
      container_name   = "backend"
      container_port   = 8000
    }
  }

  enable_autoscaling       = true
  autoscaling_min_capacity = var.backend_min_capacity
  autoscaling_max_capacity = var.backend_max_capacity

  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = 70.0
        scale_out_cooldown = 60
        scale_in_cooldown  = 300
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value       = 80.0
        scale_out_cooldown = 60
        scale_in_cooldown  = 300
      }
    }
  }

  depends_on = [module.alb]
}
