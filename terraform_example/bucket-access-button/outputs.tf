output "api_url" {
  value = "${aws_api_gateway_deployment.signer.invoke_url}/login"
}

output "cloudfront_domain_name" {
  value = "${aws_cloudfront_distribution.protected_stuff.domain_name}"
}
