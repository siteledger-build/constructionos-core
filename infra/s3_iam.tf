# Allow Lambda role to generate presigned PUTs for our bucket (specific prefix)
resource "aws_iam_role_policy" "lambda_s3_put" {
  name = "constructionos-lambda-s3-put"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Action : ["s3:PutObject", "s3:AbortMultipartUpload"],
      Resource : "${aws_s3_bucket.receipts.arn}/uploads/*"
    }]
  })
}
