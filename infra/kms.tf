# CMK for database encryption
resource "aws_kms_key" "db" {
  description             = "KMS key for ConstructionOS Aurora Postgres"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "kms-db" }
}

# CMK for Secrets Manager (can reuse db key, but split is cleaner)
resource "aws_kms_key" "secrets" {
  description             = "KMS key for ConstructionOS secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "kms-secrets" }
}

# KMS key for S3 receipts (separate from DB/secrets keys)
resource "aws_kms_key" "files" {
  description             = "KMS for ConstructionOS receipts"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "kms-files" }
}
