# Local .zip packages → uploaded to S3 (lambda_artifacts_s3 module) → Lambda references bucket/key/version.

locals {
  python_pip_platform = var.lambda_architecture == "arm64" ? "manylinux2014_aarch64" : "manylinux2014_x86_64"
  python_pip_version  = trimprefix(var.lambda_runtime_python_zip, "python")
  python_pip_ver_tag  = replace(local.python_pip_version, ".", "")
  python_pip_abi      = "cp${local.python_pip_ver_tag}"
}

resource "null_resource" "node_lambda_npm_ci" {
  triggers = {
    package_json = filemd5("${local.node_app_dir}/package.json")
    lock           = filemd5("${local.node_app_dir}/package-lock.json")
    app_js         = filemd5("${local.node_app_dir}/app.js")
    lambda_js      = filemd5("${local.node_app_dir}/lambda.js")
  }

  provisioner "local-exec" {
    command     = "mkdir -p \"${path.module}/builds\" && cd \"${local.node_app_dir}\" && npm ci --omit=dev"
    interpreter = ["/bin/sh", "-c"]
  }
}

resource "null_resource" "python_lambda_bundle" {
  triggers = {
    req            = filemd5("${local.python_app_dir}/requirements-lambda.txt")
    main_py        = filemd5("${local.python_app_dir}/main.py")
    handler        = filemd5("${local.python_app_dir}/handler.py")
    lambda_arch    = var.lambda_architecture
    python_runtime = var.lambda_runtime_python_zip
    pip_platform   = local.python_pip_platform
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p "${path.module}/builds"
      ROOT="${local.python_app_dir}"
      OUT="$ROOT/.lambda_zip_staging"
      rm -rf "$OUT"
      mkdir -p "$OUT"
      ${var.lambda_pip_command} install -r "$ROOT/requirements-lambda.txt" -t "$OUT" \
        --disable-pip-version-check \
        --platform "${local.python_pip_platform}" \
        --python-version "${local.python_pip_ver_tag}" \
        --implementation cp \
        --abi "${local.python_pip_abi}" \
        --only-binary=:all: \
        -q
      cp "$ROOT/main.py" "$ROOT/handler.py" "$OUT/"
    EOT
    interpreter = ["/bin/sh", "-c"]
  }
}

data "archive_file" "node_lambda_zip" {
  depends_on = [null_resource.node_lambda_npm_ci]

  type        = "zip"
  source_dir  = local.node_app_dir
  output_path = "${path.module}/builds/node-lambda.zip"

  excludes = [
    "Dockerfile",
    ".dockerignore",
    ".git",
    ".gitignore",
    "server.js",
    "*.md",
  ]
}

data "archive_file" "python_lambda_zip" {
  depends_on = [null_resource.python_lambda_bundle]

  type        = "zip"
  source_dir  = "${local.python_app_dir}/.lambda_zip_staging"
  output_path = "${path.module}/builds/python-lambda.zip"
}
