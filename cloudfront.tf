data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  bucket        = "taskflow-frontend-${data.aws_caller_identity.current.account_id}-ap-south-1"
  force_destroy = true

  tags = {
    Name    = "taskflow-frontend"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "taskflow-frontend-oac"
  description                       = "Private S3 access for TaskFlow frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "taskflow" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  default_root_object = "index.html"
  comment             = "TaskFlow frontend and API"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "taskflow-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = aws_lb.taskflow.dns_name
    origin_id   = "taskflow-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API requests go to the existing ALB.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "taskflow-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"
    ]

    cached_methods = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api.id
    compress                 = true
  }

  # React frontend served from private S3.
  default_cache_behavior {
    target_origin_id       = "taskflow-s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress        = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name    = "taskflow-cloudfront"
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.taskflow.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.taskflow.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.taskflow.id
}

resource "aws_cloudfront_origin_request_policy" "api" {
  name    = "taskflow-api-origin-request-policy"
  comment = "Forward API headers, cookies and query strings, excluding Host"

  headers_config {
    header_behavior = "allExcept"
    headers {
      items = ["Host"]
    }
  }

  cookies_config {
    cookie_behavior = "all"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}
