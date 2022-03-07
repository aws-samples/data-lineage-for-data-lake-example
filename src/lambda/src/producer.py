import logging
import os
from fastapi import FastAPI, Body
from typing import Dict, Any, List
from mangum import Mangum
from gremlin_python.process.graph_traversal import __
from neptune_python_utils.gremlin_utils import GremlinUtils
from parser import *
from glue_api_provider import *
from utils import addVertex, upsertVertex, updateProperties
from constants import *

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

API_STAGE = os.environ["API_STAGE"]
NEPTUNE_CLUSTER_ENDPOINT = os.environ["NEPTUNE_CLUSTER_ENDPOINT"]
NEPTUNE_CLUSTER_PORT = os.environ["NEPTUNE_CLUSTER_PORT"]
logger.info(f"Neptune endpoint: {NEPTUNE_CLUSTER_ENDPOINT}:{NEPTUNE_CLUSTER_PORT}")

app = FastAPI(root_path=f"/{API_STAGE}")
GremlinUtils.init_statics(globals())
gremlin_utils = GremlinUtils()


@app.head("/status")
def status():
    return {}


@app.post("/execution-plans")
def execution_plans(body: Dict[str, Any] = Body(...)):
    conn = gremlin_utils.remote_connection()
    g = gremlin_utils.traversal_source(connection=conn)
    logger.info(f"Received execution plan:{json.dumps(body)}")
    execution_id = body["id"]

    # Job
    job = parseJob(body)
    logger.info(f"Parsed job: {job}")

    jobName = job["name"]
    jobDetails = getGlueJob(jobName)
    logger.info(f"Got job details from Glue API: {jobDetails}")
    job["details"] = json.dumps(jobDetails, default=str)
    logger.info(f"Job details:{job}")

    jobV = upsertVertex(
        g.V().has(VERTEX_LABEL_JOB, "name", jobName),
        VERTEX_LABEL_JOB,
        job
    ).next()
    logger.info(f"Performed upsert for job vertex {jobV}")

    # Job run
    jobRun = parseJobRun(body)
    logger.info(f"Parsed job run: {jobRun}")

    jobRunDetails = getGlueJobRun(job["name"], jobRun["id"])
    logger.info(f"Got job run details from Glue API: {jobRunDetails}")
    jobRun["details"] = json.dumps(jobRunDetails, default=str)

    jobRunV = upsertVertex(
        g.V().has(VERTEX_LABEL_JOB_RUN, "run_id", jobRun["id"]),
        VERTEX_LABEL_JOB_RUN,
        jobRun
    ).next()
    logger.info(f"Performed upsert for job run {jobRunV}")

    # add if not exist a "schedule" edge from "job" to "job run"
    g.V(jobV).as_("v") \
        .V(jobRunV) \
        .coalesce(
        __.inE("schedule").where(__.outV().as_("v")),
        __.addE("schedule").from_("v")
    ).iterate()
    logger.info(f"Updated 'schedule' edge from 'job' to 'job run'")

    # Execution plan
    executionPlan = parseExecutionPlan(body)
    logger.info(f"Parsed execution plan: {executionPlan}")

    executionPlanV = addVertex(g, VERTEX_LABEL_EXECUTION_PLAN, executionPlan).next()
    logger.info(f"Added execution plan {executionPlanV}")

    g.V(jobRunV).addE("has").to(executionPlanV).next()
    logger.info(f"Updated 'has' edge from 'job run' to 'execution plan'")

    ## Parse DAG
    operations = parseDAG(body)
    logger.info(f"Parsed DAG, operations: {operations}")

    operationVertices = {}
    for opId, operation in operations.items():
        operationType = operation["type"]
        operationProps = dict(operation)
        operationProps.pop("table", None)
        operationProps.pop("children", None)
        operationV = addVertex(g, operationType, operationProps).next()
        logger.info(f"Added operation: label {operationType}, props {operationProps},  vertex {operationV}")
        operationVertices[opId] = operationV

        if "table" in operation:  # we have table for read & write ops
            table = operation["table"]
            databaseName = table["database"]
            databaseV = upsertVertex(
                g.V().has(VERTEX_LABEL_DATABASE, "name", databaseName),
                VERTEX_LABEL_DATABASE,
                {"name": databaseName}
            ).next()
            logger.info(f"Performed upsert for database: name {databaseName}, vertex {databaseV}")
            tableV = upsertVertex(
                g.V().has(VERTEX_LABEL_TABLE, "name", table["name"]).has(VERTEX_LABEL_TABLE, "database", databaseName),
                VERTEX_LABEL_TABLE,
                table
            ).next()
            logger.info(f"Performed upsert for table {table}, vertex {tableV}")

            g.V(tableV).as_("v") \
                .V(databaseV) \
                .coalesce(
                __.inE("belongs_to").where(__.outV().as_("v")),
                __.addE("belongs_to").from_("v")
            ).iterate()
            logger.info(f"Updated 'belongs_to' edge from table '{table}' to database '{databaseName}'")

            g.V(tableV).addE("used_by").to(operationV).next()
            logger.info(f"Added 'used_by' edge from table '{table}' to operation '{operationType}'")
            if operation["type"] == "WRITE_OP":
                g.V(executionPlanV).addE("produce").to(tableV).next()
                logger.info(f"Added 'produce' edge from execution plan '{executionPlanV}' to table '{table}'")
            elif operation["type"] == "READ_OP":
                g.V(tableV).addE("consumed_by").to(executionPlanV).next()
                logger.info(f"Added 'consumed_by' edge from table '{table}' to execution plan '{executionPlanV}'")

    for opID, operation in operations.items():
        if operation["type"] == "WRITE_OP":
            g.V(executionPlanV).addE("has").to(operationVertices[opID]).next()
            logger.info(f"Added 'has' edge from execution plan {executionPlanV} to operation {operation['type']}")
        if "children" in operation:
            for child in operation["children"]:
                g.V(operationVertices[child]).addE("parent_of").to(operationVertices[opID]).next()
                logger.info(f"Added 'parent_of' edge from operation {child} to operation {operation['type']}")

    logger.info("Finished execution_plans")
    conn.close()
    return execution_id


@app.post("/execution-events")
def execution_events(body: List[Dict[str, Any]] = Body(...)):
    logger.info(f"Received execution event: {json.dumps(body)}")
    conn = gremlin_utils.remote_connection()
    g = gremlin_utils.traversal_source(connection=conn)
    executionPlanID = body[0]["planId"]
    metrics = parseExecutionPlanFromExecutionEvents(body[0])
    executionPlanV = upsertVertex(
        g.V().has(VERTEX_LABEL_EXECUTION_PLAN, "id", executionPlanID),
        VERTEX_LABEL_EXECUTION_PLAN,
        metrics
    ).next()
    logger.info(f"Performed upsert for execution plan {executionPlanV} with metrics {metrics}")

    # update schema of the output table from glue data catalog
    outputTableV = g.V(executionPlanV).out("produce").next()
    tableProps = g.V(outputTableV).valueMap().next()
    logger.info(f"table props {tableProps}")
    glueTable = getGlueTable(tableProps["database"][0], tableProps["name"][0])
    logger.info(f"glue table {glueTable}")
    schema = json.dumps([
        {"name": c["Name"], "data_type": c["Type"]}
        for c in glueTable["Table"]["StorageDescriptor"]["Columns"]
    ])

    tableExtraProps = {
        "schema": schema
    }
    updateProperties(g, outputTableV, tableExtraProps).next()
    logger.info("Finished execution_events")
    conn.close()
    return executionPlanID


@app.post("/execution-failure")
def execution_failure(body: Dict[str, Any] = Body(...)):
    return {}


def lambda_handler(event, context):
    handler = Mangum(app, api_gateway_base_path=f"/{API_STAGE}")
    return handler(event, context)
