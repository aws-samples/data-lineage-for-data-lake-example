import boto3


def getGlueJob(jobName):
    client = boto3.client("glue")
    return client.get_job(JobName=jobName)["Job"]


def getGlueJobRun(jobName, jobRunID):
    client = boto3.client("glue")
    return client.get_job_run(JobName=jobName, RunId=jobRunID)["JobRun"]


def getGlueTable(databaseName, tableName):
    client = boto3.client("glue")
    return client.get_table(DatabaseName=databaseName, Name=tableName)
