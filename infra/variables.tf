variable "aws_region" {
  type        = string
  description = "Region for the S3 and Cognito resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Lowercase project name used in resource names."
  default     = "blue-green-edge-deploy"
}

variable "domain_name" {
  type        = string
  description = "Optional custom domain. Leave empty to use the CloudFront hostname."
  default     = ""
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 when domain_name is set."
  default     = null
  nullable    = true
}

variable "github_repository" {
  type        = string
  description = "GitHub owner/repository allowed to assume the deploy role."
  default     = "example/example"
}

variable "github_branch" {
  type        = string
  description = "Branch allowed to deploy through OIDC."
  default     = "main"
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to delete bucket objects. Keep false in production."
  default     = false
}
