resource "random_password" "db_master" {
  length  = 20
  special = true
}

# Store the password in Secrets Manager (for your app to retrieve)
resource "aws_secretsmanager_secret" "db_master" {
  name       = "constructionos/db/master"
  kms_key_id = aws_kms_key.secrets.arn
  tags       = { Name = "db-master-secret" }
}

resource "aws_secretsmanager_secret_version" "db_master_v1" {
  secret_id     = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({ username = "appadmin", password = random_password.db_master.result })
}
