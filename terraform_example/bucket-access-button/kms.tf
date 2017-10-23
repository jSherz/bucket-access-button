/*
    We use a KMS key to avoid saving the plaintext password in the Terraform repository or the
    Terraform state.
*/

resource "aws_kms_key" "signer" {
  description = "${var.bucket_name}-signer"
}

resource "aws_kms_alias" "a" {
  name          = "alias/bucket-access-button/${var.bucket_name}"
  target_key_id = "${aws_kms_key.signer.key_id}"
}
