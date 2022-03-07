variable "name" {
  description = "Glue job name"
}

variable "role_arn" {
  description = "Role arn"
}

variable "script_file_path" {
  description = "Script file path"
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
}

variable "lineage_endpoint" {
  description = "lineage endpoint"
}

variable "jars" {
  description = "jars"
}

variable "job_parameters" {
  description = "job parameters"
}