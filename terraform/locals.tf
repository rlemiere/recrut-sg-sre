locals {
  zone_name       = trimsuffix(data.aws_route53_zone.main.name, ".")
  frontend_domain = "${var.prefix}.${local.zone_name}"
  api_domain      = "api.${var.prefix}.${local.zone_name}"
}
