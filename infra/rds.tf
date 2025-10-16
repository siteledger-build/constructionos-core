# Parameter group for Aurora Postgres (optional defaults)
resource "aws_rds_cluster_parameter_group" "aurora_pg" {
  name   = "constructionos-aurora-pg"
  family = "aurora-postgresql15"
  description = "Aurora PG params"

  # example tune (leave defaults for now)
  parameter { name = "max_connections" value = "200" apply_method = "pending-reboot" }
}

# The cluster (engine-level)
resource "aws_rds_cluster" "db" {
  cluster_identifier              = "constructionos-aurora"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.3"
  database_name                   = "constructionos"
  master_username                 = "appadmin"
  master_password                 = random_password.db_master.result
  kms_key_id                      = aws_kms_key.db.arn
  storage_encrypted               = true
  db_subnet_group_name            = aws_db_subnet_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  backup_retention_period         = 7
  preferred_backup_window         = "01:00-02:00"
  preferred_maintenance_window    = "sun:02:00-sun:03:00"
  deletion_protection             = false
  apply_immediately               = true
  copy_tags_to_snapshot           = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_pg.name

  # Serverless v2 capacity range (2 = ~ACU 2)
  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 8
  }

  tags = { Name = "constructionos-aurora-cluster" }
}

# The serverless v2 instance(s)
resource "aws_rds_cluster_instance" "db_instance_a" {
  identifier         = "constructionos-aurora-a"
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version
  publicly_accessible = false
}

# Output connection info (no secrets)
output "db_endpoint" {
  value = aws_rds_cluster.db.endpoint
}

output "db_reader_endpoint" {
  value = aws_rds_cluster.db.reader_endpoint
}
