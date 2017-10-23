// The bucket that we're granting access to
resource "aws_s3_bucket" "protected_stuff" {
  bucket = "${var.bucket_name}"
  acl    = "private"
  policy = "${data.aws_iam_policy_document.protected_stuff.json}"
}

data "aws_iam_policy_document" "protected_stuff" {
  statement {
    sid    = "Allow CloudFront origin access ID to access everything"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    principals {
      type        = "CanonicalUser"
      identifiers = ["${aws_cloudfront_origin_access_identity.protected_stuff.s3_canonical_user_id}"]
    }
  }

  statement {
    sid       = "Allow everyone to access login.html"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/login.html"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "protected_stuff" {
  comment = "${var.bucket_name} bucket access button"
}

resource "aws_cloudfront_distribution" "protected_stuff" {
  origin {
    domain_name = "${aws_s3_bucket.protected_stuff.bucket_domain_name}"
    origin_id   = "s3"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.protected_stuff.cloudfront_access_identity_path}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.bucket_name} bucket access button"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["HEAD", "GET", "OPTIONS"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = "s3"
    trusted_signers  = ["self"]

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

  price_class = "PriceClass_200"

  viewer_certificate {
    minimum_protocol_version       = "TLSv1"
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    
  }
}
