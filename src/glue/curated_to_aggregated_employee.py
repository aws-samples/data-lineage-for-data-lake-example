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

spark.sql("use curated_db")
df = spark.sql(f"""
    SELECT 
        e1.employee_id, 
        CONCAT(e1.first_name, ' ', e1.last_name) AS employee_name,
        e1.salary,
        e1.manager_id,
        CONCAT(e2.first_name, ' ', e2.last_name) AS manager_name
    FROM employee e1, employee e2
    WHERE e1.manager_id = e2.employee_id
        AND e1.department_id = 50
    ORDER BY e1.salary DESC
""")
df.write.format("parquet") \
    .option("path", f"{args['OUTPUT_LOCATION']}") \
    .mode("overwrite") \
    .saveAsTable("aggregated_db.employee")
