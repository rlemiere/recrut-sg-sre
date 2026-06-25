resource "random_password" "db_password" {
  length  = 24
  special = false
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  identifier           = "${var.prefix}-postgres"
  engine               = "postgres"
  engine_version       = "17"
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 50

  db_name  = "urlshortener"
  username = "urlshortener"
  port     = 5432

  manage_master_user_password = false
  password_wo                 = random_password.db_password.result
  password_wo_version         = 1

  multi_az            = false
  availability_zone   = "${var.aws_region}a"
  publicly_accessible = false

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period      = 7
  performance_insights_enabled = false
  monitoring_interval          = 0
  deletion_protection          = false
  skip_final_snapshot          = true
}
