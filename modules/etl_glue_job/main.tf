resource "aws_s3_bucket_object" "job_script" {
  bucket = var.s3_bucket_name
  key    = "script/${basename(var.script_file_path)}"
  source = var.script_file_path
  etag   = filemd5(var.script_file_path)
}

resource "aws_glue_job" "job" {
  name              = var.name
  role_arn          = var.role_arn
  command {
    python_version  = 3
    script_location = "s3://${var.s3_bucket_name}/script/${basename(var.script_file_path)}"
  }
  glue_version      = "2.0"
  number_of_workers = 2
  worker_type       = "Standard"
  default_arguments = merge (
    {
      "--TempDir" : "s3://${var.s3_bucket_name}/temp_dir",
      "--conf" : "spark.spline.producer.url=${var.lineage_endpoint} --conf spark.sql.queryExecutionListeners=za.co.absa.spline.harvester.listener.SplineQueryExecutionListener",
      "--extra-jars" : var.jars,
      "--job-language" : "python",
      "--user-jars-first" : "true",
      "--enable-glue-datacatalog": ""
    },
    var.job_parameters
  )
}

