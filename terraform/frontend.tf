data "aws_caller_identity" "current" {}

module "s3_frontend" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.14.1"

  bucket = "${var.prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}


module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.0"

  aliases             = [local.frontend_domain]
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  origin_access_control = {
    s3-frontend = {
      description      = "CloudFront to S3 frontend"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3-frontend = {
      domain_name               = module.s3_frontend.s3_bucket_bucket_regional_domain_name
      origin_access_control_key = "s3-frontend"
    }
    alb-backend = {
      domain_name = local.api_domain
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/l/*"
      target_origin_id       = "alb-backend"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_name      = "Managed-CachingDisabled"
    },
    {
      path_pattern           = "/links"
      target_origin_id       = "alb-backend"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_name      = "Managed-CachingDisabled"
    }
  ]

  custom_error_response = [
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]

  viewer_certificate = {
    acm_certificate_arn      = module.acm_cloudfront.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_iam_policy_document" "s3_cf" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_frontend.s3_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_cf" {
  bucket = module.s3_frontend.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_cf.json
}

action "aws_cloudfront_create_invalidation" "frontend" {
  config {
    distribution_id = module.cloudfront.cloudfront_distribution_id
    paths           = ["/*"]
  }
}

resource "terraform_data" "frontend_sync" {
  triggers_replace = var.frontend_version

  provisioner "local-exec" {
    command = "aws s3 sync ${var.frontend_dist_dir} s3://${module.s3_frontend.s3_bucket_id}/ --delete --region ${var.aws_region}"
  }

  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.aws_cloudfront_create_invalidation.frontend]
    }
  }

  depends_on = [aws_s3_bucket_policy.frontend_cf]
}
