variable "name_prefix" {
  type = string
}

variable "stage_name" {
  type        = string
  description = "Stage name (e.g. dev, local)."
  default     = "dev"
}

variable "proxy_routes" {
  type = map(object({
    path_part         = string
    lambda_invoke_arn = string
  }))
  description = "One path segment (e.g. node) → Lambda; exposes /{path_part} and /{path_part}/{proxy+}."
}
