################################################################
# S3 buckets for data lake
################################################################

module "s3_bucket_raw" {
  source = "./modules/data_lake_s3_bucket"
  name   = "data-lake-raw-${local.post_fix}"
}

resource "aws_s3_bucket_object" "employee" {
  bucket = module.s3_bucket_raw.bucket.bucket
  key    = "employee/employee.csv"
  source = "asset/sample_data/employee.csv"
  etag   = filemd5("asset/sample_data/employee.csv")
}

module "s3_bucket_curated" {
  source = "./modules/data_lake_s3_bucket"
  name   = "data-lake-curated-${local.post_fix}"
}

module "s3_bucket_aggregated" {
  source = "./modules/data_lake_s3_bucket"
  name   = "data-lake-aggregated-${local.post_fix}"
}


################################################################
# Neptune database
################################################################

locals {
  neptune_db_port = 8182
}

resource "aws_neptune_subnet_group" "default" {
  name       = "data-lineage-neptune-subnet-group"
  subnet_ids = data.aws_subnet_ids.default.ids
}

resource aws_security_group "sg_neptune_db" {
  name = "sg_lineage_neptune_db"
  ingress {
    from_port  = local.neptune_db_port
    to_port = local.neptune_db_port
    protocol = "tcp"
    cidr_blocks = [data.aws_vpc.current.cidr_block]
  }
  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = data.aws_vpc.current.id
}

resource "aws_neptune_cluster" "default" {
  cluster_identifier                  = "data-lineage-neptune-cluster"
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = false
  apply_immediately                   = true
  neptune_subnet_group_name = aws_neptune_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.sg_neptune_db.id]
  port = local.neptune_db_port
}

resource "aws_neptune_cluster_instance" "data_lineage_instance" {
  identifier = "data-lineage-neptune-instance"
  cluster_identifier  = aws_neptune_cluster.default.id
  apply_immediately   = true
  instance_class      = "db.t3.medium"
  neptune_subnet_group_name = aws_neptune_subnet_group.default.name
  port = local.neptune_db_port
}
