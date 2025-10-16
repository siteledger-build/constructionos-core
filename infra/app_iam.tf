# Add Secrets Manager read to the Lambda role (defined earlier in main.tf)
resource "aws_iam_role_policy" "lambda_secrets_read" {
  name = "constructionos-lambda-secrets-read"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.db_master.arn
    }]
  })
}
