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

resource "aws_api_gateway_method" "signer_cors" {
  rest_api_id   = "${aws_api_gateway_rest_api.signer.id}"
  resource_id   = "${aws_api_gateway_resource.signer.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "signer_cors" {
  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  resource_id = "${aws_api_gateway_resource.signer.id}"
  http_method = "${aws_api_gateway_method.signer_cors.http_method}"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\":200}"
  }
}

resource "aws_api_gateway_integration_response" "signer_cors" {
  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  resource_id = "${aws_api_gateway_resource.signer.id}"
  http_method = "${aws_api_gateway_method.signer_cors.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method_response" "signer_cors" {
  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  resource_id = "${aws_api_gateway_resource.signer.id}"
  http_method = "OPTIONS"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_deployment" "signer" {
  depends_on = ["aws_api_gateway_method.signer"]

  rest_api_id = "${aws_api_gateway_rest_api.signer.id}"
  stage_name  = "default"
}
