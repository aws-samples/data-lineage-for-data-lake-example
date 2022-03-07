resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.name
  acl    = "private"
}

resource "aws_s3_account_public_access_block" "s3_account_public_access_block" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
