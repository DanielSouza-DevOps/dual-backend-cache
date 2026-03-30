variable "name_prefix" {
  type = string
}

variable "service_key" {
  type = string
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket containing the code .zip."
}

variable "s3_key" {
  type        = string
  description = "S3 object key for the .zip."
}

variable "s3_object_version" {
  type        = string
  nullable    = true
  default     = null
  description = "Object VersionId (with bucket versioning). Optional; if empty, Lambda uses the current revision of the key."
}

variable "source_code_hash" {
  type        = string
  description = "Base64 SHA256 of the .zip (e.g. data.archive_file.*.output_base64sha256)."
}

variable "handler" {
  type        = string
  description = "Lambda handler (e.g. lambda.handler)."
}

variable "runtime" {
  type        = string
  description = "Runtime (e.g. nodejs18.x, python3.11)."
}

variable "timeout" {
  type = number
}

variable "memory_size" {
  type = number
}

variable "architecture" {
  type        = string
  description = "x86_64 or arm64."
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "Lambda environment variables."
}
