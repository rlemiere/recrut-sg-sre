data "aws_route53_zone" "main" {
  zone_id      = var.dns_zone_id
  private_zone = false
}

module "acm_regional" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.0"

  domain_name         = local.api_domain
  zone_id             = data.aws_route53_zone.main.zone_id
  validation_method   = "DNS"
  wait_for_validation = true
}

module "acm_cloudfront" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.0"

  providers = { aws = aws.us_east_1 }

  domain_name               = local.frontend_domain
  subject_alternative_names = [local.api_domain]
  zone_id                   = data.aws_route53_zone.main.zone_id
  validation_method         = "DNS"
  wait_for_validation       = true
}
