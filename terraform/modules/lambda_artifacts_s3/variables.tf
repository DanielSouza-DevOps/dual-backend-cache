variable "name_prefix" {
  type        = string
  description = "Prefix used to build the bucket name (via truncated bucket_prefix)."
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket destroy when it still contains objects."
  default     = true
}

variable "node_zip_source" {
  type        = string
  description = "Local path to the Node .zip (e.g. data.archive_file.node_lambda_zip.output_path)."
}

variable "python_zip_source" {
  type        = string
  description = "Local path to the Python .zip."
}

variable "node_object_key" {
  type        = string
  description = "S3 key for the Node package."
  default     = "packages/node/lambda.zip"
}

variable "python_object_key" {
  type        = string
  description = "S3 key for the Python package."
  default     = "packages/python/lambda.zip"
}
