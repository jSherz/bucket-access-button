data "aws_region" "current" {
  current = true
}

resource "aws_api_gateway_rest_api" "signer" {
  name = "bucket-access-button-${var.bucket_name}"
}

resource "aws_api_gateway_resource" "signer" {
  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  parent_id   = "${aws_api_gateway_rest_api.signer.root_resource_id}"
  path_part   = "login"
}

resource "aws_api_gateway_method" "signer" {
  rest_api_id   = "${aws_api_gateway_rest_api.signer.id}"
  resource_id   = "${aws_api_gateway_resource.signer.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "signer" {
  rest_api_id             = "${aws_api_gateway_rest_api.signer.id}"
  resource_id             = "${aws_api_gateway_resource.signer.id}"
  http_method             = "${aws_api_gateway_method.signer.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.signer.arn}/invocations"
}

resource "aws_api_gateway_deployment" "signer" {
  depends_on = ["aws_api_gateway_method.signer"]

  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  stage_name  = "default"
}
