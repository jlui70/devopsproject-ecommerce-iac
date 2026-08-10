data "archive_file" "layer" {
  type        = "zip"
  source_dir  = var.lambda.layer_source_path
  output_path = "${path.module}/.build/layer.zip"
}

resource "aws_lambda_layer_version" "this" {
  count = var.production_enabled ? 1 : 0

  layer_name          = "devopsproject-node-modules"
  filename            = data.archive_file.layer.output_path
  source_code_hash    = data.archive_file.layer.output_base64sha256
  compatible_runtimes = ["nodejs18.x"]

  description = "node_modules compartilhados entre as Lambdas do devopsproject"
}
