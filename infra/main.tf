# --- Random suffix (keeps names unique)
resource "random_id" "suffix" {
  byte_length = 4
}

# --- Package Lambda from backend/hello directory
data "archive_file" "hello_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/hello"
  output_path = "${path.module}/build/hello.zip"
}

# --- IAM role the Lambda will assume
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "constructionos-lambda-role-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# --- Basic execution policy (logs)
resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- The Lambda function (Node.js 20)
resource "aws_lambda_function" "hello" {
  function_name = "constructionos-hello-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.hello_zip.output_path
  source_code_hash = data.archive_file.hello_zip.output_base64sha256

  architectures = ["arm64"]
  timeout       = 5

  # NEW: run Lambda inside our VPC
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.app.id]
  }

  # NEW: env vars your handler can read
  environment {
    variables = {
      DB_PROXY_ENDPOINT = aws_db_proxy.pg.endpoint
      DB_NAME           = aws_rds_cluster.db.database_name
      DB_SECRET_ARN     = aws_secretsmanager_secret.db_master.arn
      DB_PORT           = "5432"
    }
  }
}

# --- HTTP API Gateway (v2)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "constructionos-http-${random_id.suffix.hex}"
  protocol_type = "HTTP"
}

# --- Integration: API -> Lambda
resource "aws_apigatewayv2_integration" "hello_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.hello.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 3000
}

# --- Route: GET /health -> Lambda
resource "aws_apigatewayv2_route" "health_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.hello_integration.id}"
}

# --- Stage: auto-deploy
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# --- Permission so API Gateway can invoke Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- Outputs
output "api_base_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "health_url" {
  value = "${aws_apigatewayv2_api.http_api.api_endpoint}/health"
}

# --- Zip the upload lambda
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/upload"
  output_path = "${path.module}/build/upload.zip"
}

# --- Lambda for presigning S3 uploads
resource "aws_lambda_function" "upload_presign" {
  function_name = "constructionos-upload-presign-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  architectures = ["arm64"]
  timeout       = 5

  # Env so function knows bucket & KMS key
  environment {
    variables = {
      BUCKET  = aws_s3_bucket.receipts.bucket
      KMS_KEY = aws_kms_key.files.arn
    }
  }
}

# --- API Integration and route: POST /uploads/receipt-url
resource "aws_apigatewayv2_integration" "upload_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload_presign.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /uploads/receipt-url"
  target    = "integrations/${aws_apigatewayv2_integration.upload_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_upload" {
  statement_id  = "AllowAPIGatewayInvokeUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_presign.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- Zip the OCR lambda
data "archive_file" "ocr_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/ocr"
  output_path = "${path.module}/build/ocr.zip"
}

# --- OCR Lambda
resource "aws_lambda_function" "ocr" {
  function_name = "constructionos-ocr-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.ocr_zip.output_path
  source_code_hash = data.archive_file.ocr_zip.output_base64sha256

  architectures = ["arm64"]
  timeout       = 20

  environment {
    variables = {
      KMS_KEY = aws_kms_key.files.arn
    }
  }
}

# --- Allow S3 to invoke the OCR lambda
resource "aws_lambda_permission" "allow_s3_invoke_ocr" {
  statement_id  = "AllowS3InvokeOCR"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ocr.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.receipts.arn
}

# --- Wire S3 -> Lambda on object created (uploads/*)
resource "aws_s3_bucket_notification" "receipts_events" {
  bucket = aws_s3_bucket.receipts.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ocr.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_ocr]
}

# --- Zip the list receipts lambda
data "archive_file" "list_receipts_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/receipts"
  output_path = "${path.module}/build/list-receipts.zip"
}

resource "aws_lambda_function" "list_receipts" {
  function_name = "constructionos-list-receipts-${random_id.suffix.hex}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "list.handler"
  runtime       = "nodejs20.x"

  filename         = data.archive_file.list_receipts_zip.output_path
  source_code_hash = data.archive_file.list_receipts_zip.output_base64sha256

  architectures = ["arm64"]
  timeout       = 6

  environment {
    variables = {
      BUCKET = aws_s3_bucket.receipts.bucket
    }
  }
}

# API integration + route: GET /receipts
resource "aws_apigatewayv2_integration" "list_receipts_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_receipts.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_receipts_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /receipts"
  target    = "integrations/${aws_apigatewayv2_integration.list_receipts_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw_list_receipts" {
  statement_id  = "AllowAPIGatewayInvokeListReceipts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_receipts.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
