data "aws_iam_policy_document" "signer_lambda_assume" {
  statement {
    sid     = "AllowFromLambda"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

// A role that our Lambda function will use
resource "aws_iam_role" "signer_lambda" {
  name               = "${var.bucket_name}-cookie-signer"
  assume_role_policy = "${data.aws_iam_policy_document.signer_lambda_assume.json}"
}

data "aws_iam_policy_document" "signer_lambda" {
  statement {
    sid       = "AllowDecryptionOfPassword"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["${aws_kms_key.signer.arn}"]
  }

  statement {
    sid    = "AllowPuttingLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "signer_lambda" {
  role   = "${aws_iam_role.signer_lambda.name}"
  policy = "${data.aws_iam_policy_document.signer_lambda.json}"
}

data "archive_file" "signer" {
  type        = "zip"
  source_file = "${path.module}/../../bucket_access_button.js"
  output_path = "${path.module}/bucket-access-button.zip"
}

resource "aws_lambda_function" "signer" {
  filename         = "${path.module}/bucket-access-button.zip"
  function_name    = "${var.bucket_name}-bucket-access-button"
  role             = "${aws_iam_role.signer_lambda.arn}"
  handler          = "bucket_access_button.handler"
  source_code_hash = "${data.archive_file.signer.output_base64sha256}"
  runtime          = "nodejs6.10"

  environment {
    variables = {
      ENCRYPTED_PASSWORD               = "${var.encrypted_password}"
      ENCRYPTED_CLOUDFRONT_PRIVATE_KEY = "${var.encrypted_cloudfront_private_key}"
      CLOUDFRONT_KEYPAIR_ID            = "${var.cloudfront_keypair_id}"
      CLOUDFRONT_DOMAIN_NAME           = "${aws_cloudfront_distribution.protected_stuff.domain_name}"
    }
  }
}

resource "aws_lambda_permission" "signer_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.signer.arn}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${var.aws_account_id}:${aws_api_gateway_rest_api.signer.id}/*/${aws_api_gateway_method.signer.http_method}${aws_api_gateway_resource.signer.path}"
}
