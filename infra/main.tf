# Unique, lowercase bucket name with random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "constructionos-test-${random_id.suffix.hex}"

  tags = {
    Name        = "ConstructionOS Test"
    Environment = "Dev"
  }
}
