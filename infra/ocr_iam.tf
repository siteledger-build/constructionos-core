# Let Lambda read uploads and write parsed JSON
resource "aws_iam_role_policy" "lambda_s3_readwrite_ocr" {
  name = "constructionos-lambda-s3-ocr"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : ["s3:GetObject"],
        Resource : "${aws_s3_bucket.receipts.arn}/uploads/*"
      },
      {
        Effect : "Allow",
        Action : ["s3:PutObject", "s3:AbortMultipartUpload"],
        Resource : "${aws_s3_bucket.receipts.arn}/parsed/*"
      }
    ]
  })
}

# Textract AnalyzeExpense permission
resource "aws_iam_role_policy" "lambda_textract" {
  name = "constructionos-lambda-textract"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Action : [
        "textract:AnalyzeExpense"
      ],
      Resource : "*"
    }]
  })
}
