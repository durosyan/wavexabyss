provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket = "durosyan.tfstates"
    key    = "wavexabyss.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_s3_bucket" "site" {
  bucket = "wavexabyss.co.uk"
  acl    = "private"
  policy = file("policy.json")
  tags = {
    project = "wavexabyss"
  }
  versioning {
      enabled    = false
      mfa_delete = false
  }
  website {
    index_document = "index.html"
  }
}

locals {
  s3_origin_id = "S3-wavexabyss.co.uk"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.site.bucket_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/E1W2VQ3EK37X16"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["wavexabyss.co.uk", "www.wavexabyss.co.uk"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    project = "wavexabyss"
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:654447240886:certificate/b6c3dd1f-60e4-4739-a52a-9f8c2a58649d"
    ssl_support_method  = "sni-only"
  }
}