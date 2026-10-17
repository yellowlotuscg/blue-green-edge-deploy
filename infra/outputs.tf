output "bucket_name" { value = aws_s3_bucket.site.bucket }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.site.id }
output "cloudfront_domain_name" { value = aws_cloudfront_distribution.site.domain_name }
output "active_color_kvs_arn" { value = aws_cloudfront_key_value_store.active_color.arn }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.users.id }
output "cognito_app_client_id" { value = aws_cognito_user_pool_client.web.id }
output "github_deploy_role_arn" { value = aws_iam_role.deploy.arn }
