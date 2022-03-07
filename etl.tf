################################################################
# Glue data catalog
################################################################

resource "aws_glue_catalog_database" "data_lake_raw_db" {
  name = "raw_db"
}

resource "aws_glue_catalog_database" "data_lake_curated_db" {
  name = "curated_db"
}

resource "aws_glue_catalog_database" "data_lake_aggregated_db" {
  name = "aggregated_db"
}

resource "aws_glue_catalog_table" "employee" {
  name          = "employee"
  database_name = aws_glue_catalog_database.data_lake_raw_db.name
  table_type    = "EXTERNAL_TABLE"
  storage_descriptor {
    compressed    = false
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    location      = "s3://${module.s3_bucket_raw.bucket.bucket}/employee/"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      name                  = "LazySimpleSerDe"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim" : ","
      }
    }
    columns {
      name = "employee_id"
      type = "bigint"
    }
    columns {
      name = "first_name"
      type = "string"
    }
    columns {
      name = "last_name"
      type = "string"
    }
    columns {
      name = "email"
      type = "string"
    }
    columns {
      name = "phone_number"
      type = "string"
    }
    columns {
      name = "hire_date"
      type = "string"
    }
    columns {
      name = "job_id"
      type = "string"
    }
    columns {
      name = "salary"
      type = "bigint"
    }
    columns {
      name = "commission_pct"
      type = "bigint"
    }
    columns {
      name = "manager_id"
      type = "bigint"
    }
    columns {
      name = "department_id"
      type = "bigint"
    }
  }
}


################################################################
# Glue jobs for ETL
################################################################

resource "aws_s3_bucket" "glue" {
  bucket = "glue-${local.post_fix}"
  acl    = "private"
}

resource "aws_s3_account_public_access_block" "glue" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "glue_execution_role" {
  name               = "GlueExecutionRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  for_each   = toset([
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  ])
  role       = aws_iam_role.glue_execution_role.name
  policy_arn = each.value
}

resource "aws_s3_bucket_object" "spline_agent_jar" {
  bucket = aws_s3_bucket.glue.bucket
  key    = "lib/${basename(local.spline_agent_file_path)}"
  source = local.spline_agent_file_path
  etag   = filemd5(local.spline_agent_file_path)
}

module "glue_job_raw_to_curated_employee_optimize" {
  source           = "./modules/etl_glue_job"
  name             = "RawToCurated_employee_optimize"
  role_arn         = aws_iam_role.glue_execution_role.arn
  script_file_path = "src/glue/raw_to_curated_employee_optimize.py"
  s3_bucket_name   = aws_s3_bucket.glue.bucket
  lineage_endpoint = aws_apigatewayv2_stage.data_lineage.invoke_url
  jars             = "s3://${aws_s3_bucket_object.spline_agent_jar.bucket}/${aws_s3_bucket_object.spline_agent_jar.key}"
  job_parameters = {
    "--OUTPUT_LOCATION": "s3://${module.s3_bucket_curated.bucket.bucket}/employee/"
  }
}

module "glue_job_curated_to_aggregated_employee" {
  source           = "./modules/etl_glue_job"
  name             = "CuratedToAggregated_employee"
  role_arn         = aws_iam_role.glue_execution_role.arn
  script_file_path = "src/glue/curated_to_aggregated_employee.py"
  s3_bucket_name   = aws_s3_bucket.glue.bucket
  lineage_endpoint = aws_apigatewayv2_stage.data_lineage.invoke_url
  jars             = "s3://${aws_s3_bucket_object.spline_agent_jar.bucket}/${aws_s3_bucket_object.spline_agent_jar.key}"
  job_parameters = {
    "--OUTPUT_LOCATION": "s3://${module.s3_bucket_aggregated.bucket.bucket}/employee/"
  }
}