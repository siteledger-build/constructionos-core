resource "aws_iam_role_policy" "lambda_s3_list_receipts" {
  name = "constructionos-lambda-s3-list-receipts"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : ["s3:ListBucket"],
        Resource : aws_s3_bucket.receipts.arn,
        Condition : { "StringLike" : { "s3:prefix" : ["uploads/*", "parsed/*"] } }
      },
      {
        Effect : "Allow",
        Action : ["s3:HeadObject", "s3:GetObject"],
        Resource : [
          "${aws_s3_bucket.receipts.arn}/uploads/*",
          "${aws_s3_bucket.receipts.arn}/parsed/*"
        ]
      }
    ]
  })
}
