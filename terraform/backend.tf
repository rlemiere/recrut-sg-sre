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

# ALB: accept HTTPS from VPC CIDR (CloudFront VPC Origin creates ENIs here)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
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

# ECS: reach ECR / CloudWatch / SSM via VPC endpoints
resource "aws_vpc_security_group_egress_rule" "ecs_to_vpc_endpoints" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
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
  subnets  = module.vpc.private_subnets
  internal = true

  security_groups = [aws_security_group.alb.id]

  target_groups = {
    backend = {
      protocol    = "HTTP"
      port        = 8000
      target_type = "ip"
      health_check = {
        enabled  = true
        path     = "/docs"
        protocol = "HTTP"
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

# ─── CloudWatch + SSM ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.prefix}/backend"
  retention_in_days = 14
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.prefix}/db_password"
  type  = "SecureString"
  value = random_password.db_password.result
}

# ─── IAM ───────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_ssm" {
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "kms:Decrypt"]
      Resource = [aws_ssm_parameter.db_password.arn]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# ─── ECS Task Definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.prefix}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image_uri
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
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/docs || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# ─── ECS Service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "backend" {
  name            = "${var.prefix}-backend"
  cluster         = module.ecs_cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.alb.target_groups["backend"].arn
    container_name   = "backend"
    container_port   = 8000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [module.alb]
}

# ─── Autoscaling ───────────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "ecs" {
  resource_id        = "service/${module.ecs_cluster.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  min_capacity       = var.backend_min_capacity
  max_capacity       = var.backend_max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.prefix}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
}
