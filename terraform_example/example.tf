module "bucket-access-button" {
  source = "./bucket-access-button"

  aws_account_id                   = "${var.aws_account_id}"
  bucket_name                      = "jsjs-top-secret-bucket"
  encrypted_password               = "${var.encrypted_password}"
  cloudfront_keypair_id            = "${var.cloudfront_keypair_id}"
  encrypted_cloudfront_private_key = "${var.encrypted_cloudfront_private_key}"
}
