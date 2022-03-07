import logging
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from gremlin_python.process.graph_traversal import __
from neptune_python_utils.gremlin_utils import GremlinUtils
from constants import *
from gremlin_python.process.traversal import T

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

API_STAGE = os.environ["API_STAGE"]
NEPTUNE_CLUSTER_ENDPOINT = os.environ["NEPTUNE_CLUSTER_ENDPOINT"]
NEPTUNE_CLUSTER_PORT = os.environ["NEPTUNE_CLUSTER_PORT"]
logger.info(f"Neptune endpoint: {NEPTUNE_CLUSTER_ENDPOINT}:{NEPTUNE_CLUSTER_PORT}")

app = FastAPI(root_path=f"/{API_STAGE}")
origins = [
    "http://localhost",
    "http://localhost:8080",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
GremlinUtils.init_statics(globals())
gremlin_utils = GremlinUtils()


@app.get("/status")
def status():
    return {"message": "Hello from Consumer"}


@app.get("/jobs")
def getJobsView():
    conn = gremlin_utils.remote_connection()
    g = gremlin_utils.traversal_source(connection=conn)
    jobs = g.V().hasLabel(VERTEX_LABEL_JOB).elementMap().toList()
    tables = g.V().hasLabel(VERTEX_LABEL_TABLE).elementMap().toList()
    edgesJobsToOutputTables = g.V().hasLabel(VERTEX_LABEL_JOB).as_("from") \
        .out("schedule").out("has").out("produce").as_("to") \
        .select("from", "to").by(T.id).toList()
    edgesInputTablesToJobs = g.V().hasLabel(VERTEX_LABEL_JOB).as_("to") \
        .out("schedule").out("has").out("has") \
        .repeat(__.in_("parent_of")).until(__.hasLabel("READ_OP")) \
        .in_("used_by").as_("from") \
        .select("from", "to").by(T.id).dedup().toList()
    edges = edgesJobsToOutputTables + edgesInputTablesToJobs
    conn.close()
    return {
        "jobs": jobs,
        "tables": tables,
        "edges": edges
    }


@app.get("/job/{id}")
def getJobView(id):
    conn = gremlin_utils.remote_connection()
    g = gremlin_utils.traversal_source(connection=conn)
    job = g.V().has(VERTEX_LABEL_JOB, "name", id).elementMap().next()
    outputTables = g.V(job[T.id]).out("schedule").out("has").out("produce").dedup().elementMap().toList()
    inputTables = g.V(job[T.id]).out("schedule").out("has").in_("consumed_by").dedup().elementMap().toList()

    edgesJobsToOutputTables = g.V().has(VERTEX_LABEL_JOB, "name", id).as_("from") \
        .out("schedule").out("has").out("produce").as_("to") \
        .select("from", "to").by(T.id).toList()
    edgesInputTablesToJobs = g.V(job[T.id]).as_("to").out("schedule").out("has") \
        .in_("consumed_by").as_("from") \
        .select("from", "to").by(T.id).dedup().toList()
    edges = edgesJobsToOutputTables + edgesInputTablesToJobs

    jobRuns = g.V(job[T.id]).out("schedule").elementMap().toList()
    executionPlans = g.V(job[T.id]).out("schedule").out("has").elementMap().toList()
    conn.close()
    return {
        "jobs": [job],
        "tables": inputTables + outputTables,
        "edges": edges,
        "job_runs": jobRuns,
        "execution_plans": executionPlans,
    }


@app.get("/dag/{id}")
def getDAGsView(id):
    conn = gremlin_utils.remote_connection()
    g = gremlin_utils.traversal_source(connection=conn)
    executionPlanID = id
    writeOpID = g.V().has(VERTEX_LABEL_EXECUTION_PLAN, "id", executionPlanID).out("has").id().next()
    outputTableNode = g.V().has(VERTEX_LABEL_EXECUTION_PLAN, "id", executionPlanID).out("produce").next()
    paths = g.V(outputTableNode).out("used_by").hasId(writeOpID) \
        .repeat(__.in_("parent_of")).until(__.hasLabel("READ_OP")) \
        .in_("used_by") \
        .path().by(__.elementMap()).toList()

    nodes = []
    edges = []
    for path in paths:
        nodes = nodes + path.objects
        for i in range(1, len(path)):
            edges.append({
                "from": path[i][T.id],
                "to": path[i - 1][T.id]
            })

    # deduplicate
    nodes = [dict(t) for t in {tuple(d.items()) for d in nodes}]
    edges = [dict(t) for t in {tuple(d.items()) for d in edges}]

    nodes = {node[T.id]: node for node in nodes}
    for path in paths:
        level = 0
        for i in range(len(path) - 1, -1, -1):
            nodeID = path[i][T.id]
            if not "level" in nodes[nodeID]:
                nodes[nodeID]["level"] = level
            else:
                nodes[nodeID]["level"] = max(nodes[nodeID]["level"], level + 1)
            level = level + 1

    nodes = list(nodes.values())
    conn.close()
    return {
        "nodes": nodes,
        "edges": edges,
    }


def lambda_handler(event, context):
    logger.info(f"Function triggered by an event: {event}")
    handler = Mangum(app, api_gateway_base_path=f"/{API_STAGE}")
    response = handler(event, context)
    logger.info(f"Function finished, returning a response: {response}")
    return response
