import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job


args = getResolvedOptions(sys.argv, ["JOB_NAME", "OUTPUT_LOCATION"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

spark.sql("use raw_db")
df = spark.sql(f"""
    SELECT *
    FROM employee
""")
df.write.format("parquet") \
    .option("path", f"{args['OUTPUT_LOCATION']}") \
    .mode("overwrite") \
    .saveAsTable("curated_db.employee")
