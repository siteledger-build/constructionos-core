# Private bucket for receipts
resource "aws_s3_bucket" "receipts" {
  bucket = "constructionos-receipts-${random_id.suffix.hex}"
  tags = { Name = "receipts-bucket", Environment = "dev" }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "receipts" {
  bucket                  = aws_s3_bucket.receipts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Default SSE-KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.files.arn
    }
  }
}

# Versioning (helps with “oops” deletes)
resource "aws_s3_bucket_versioning" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  versioning_configuration { status = "Enabled" }
}

# Lifecycle: clean up failed multipart + move old objects to IA after 30d
resource "aws_s3_bucket_lifecycle_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id

  rule {
    id     = "abort-mpu"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }

  rule {
    id     = "transition-ia-30d"
    status = "Enabled"
    filter {}
    transition { days = 30 storage_class = "STANDARD_IA" }
  }
}

# Bucket policy: require TLS and KMS SSE
resource "aws_s3_bucket_policy" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "DenyInsecureTransport",
        Effect: "Deny",
        Principal: "*",
        Action: "s3:*",
        Resource: [
          aws_s3_bucket.receipts.arn,
          "${aws_s3_bucket.receipts.arn}/*"
        ],
        Condition: { Bool: { "aws:SecureTransport": "false" } }
      },
      {
        Sid: "DenyUnEncryptedUploads",
        Effect: "Deny",
        Principal: "*",
        Action: "s3:PutObject",
        Resource: "${aws_s3_bucket.receipts.arn}/*",
        Condition: {
          StringNotEquals: { "s3:x-amz-server-side-encryption": "aws:kms" }
        }
      }
    ]
  })
}
