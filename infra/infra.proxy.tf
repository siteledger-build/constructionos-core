# IAM role for RDS Proxy to fetch the secret
data "aws_iam_policy_document" "rds_proxy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["rds.amazonaws.com"] }
  }
}

resource "aws_iam_role" "rds_proxy_role" {
  name               = "constructionos-rds-proxy-role"
  assume_role_policy = data.aws_iam_policy_document.rds_proxy_assume.json
}

resource "aws_iam_role_policy" "rds_proxy_secret_access" {
  name = "constructionos-rds-proxy-secret-access"
  role = aws_iam_role.rds_proxy_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.db_master.arn
    }]
  })
}

resource "aws_db_proxy" "pg" {
  name                   = "constructionos-pg-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  vpc_security_group_ids = [aws_security_group.app.id] # Proxy sits with the app SG
  require_tls            = true
  idle_client_timeout    = 1800
  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_master.arn
  }
  tags = { Name = "pg-proxy" }
}

resource "aws_db_proxy_default_target_group" "pg" {
  db_proxy_name = aws_db_proxy.pg.name
  connection_pool_config {
    max_connections_percent      = 90
    max_idle_connections_percent = 50
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "pg_cluster" {
  db_proxy_name         = aws_db_proxy.pg.name
  target_group_name     = aws_db_proxy_default_target_group.pg.name
  db_cluster_identifier = aws_rds_cluster.db.id
}

output "db_proxy_endpoint" {
  value = aws_db_proxy.pg.endpoint
}
