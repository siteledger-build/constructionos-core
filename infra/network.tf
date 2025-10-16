# ---- VPC (two AZs, private subnets for DB)
resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "constructionos-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "constructionos-igw" }
}

# Public subnets (for future NAT/Lambda if needed)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.0.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.igw.id }
  tags  = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_a" { subnet_id = aws_subnet.public_a.id route_table_id = aws_route_table.public.id }
resource "aws_route_table_association" "public_b" { subnet_id = aws_subnet.public_b.id route_table_id = aws_route_table.public.id }

# Private subnets for DB
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "private-b" }
}

# Security group for RDS; we’ll only allow traffic from app SG (placeholder)
resource "aws_security_group" "db" {
  name        = "constructionos-db-sg"
  description = "Allow Postgres from app security group only"
  vpc_id      = aws_vpc.main.id
  # No ingress yet; will add once app SG exists. For apply later we allow self -> 0 traffic.
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "db-sg" }
}

# DB subnet group (RDS requires two+ subnets in different AZs)
resource "aws_db_subnet_group" "db" {
  name       = "constructionos-db-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "db-subnet-group" }
}

# App security group for Lambdas
resource "aws_security_group" "app" {
  name        = "constructionos-app-sg"
  description = "App functions in VPC"
  vpc_id      = aws_vpc.main.id
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "app-sg" }
}

# Allow Postgres from app SG to DB SG
resource "aws_security_group_rule" "db_ingress_pg" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
}
