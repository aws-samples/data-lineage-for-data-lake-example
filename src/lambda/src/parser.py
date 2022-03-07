import json


def parseJob(payload):
    appName = payload["extraInfo"]["appName"]
    parts = appName.split("-")
    return {
        "name": "-".join(parts[1:-1])
    }


def parseJobRun(payload):
    appName = payload["extraInfo"]["appName"]
    parts = appName.split("-")
    glueJobRunID = parts[-1]
    return {
        "id": glueJobRunID
    }


def parseExecutionPlan(payload):
    return {
        "id": payload["id"],
        "spark_version": f'{payload["systemInfo"]["name"]} {payload["systemInfo"]["version"]}',
        "spline_version": f'{payload["agentInfo"]["name"]} {payload["agentInfo"]["version"]}'
    }


def parseDAG(payload):
    dataTypes = payload["extraInfo"]["dataTypes"]
    attributes = payload["extraInfo"]["attributes"]
    columns = {}
    for att in attributes:
        dataType = [d["name"] for d in dataTypes if d["id"] == att["dataTypeId"]]
        if len(dataType) == 0:
            raise Exception(f"DataType not found {att['dataTypeId']}")
        dataType = dataType[0]
        columns[att["id"]] = {
            "name": att["name"],
            "data_type": dataType
        }

    operationData = payload["operations"]
    writeOpData = operationData["write"]
    readOpsData = operationData["reads"]
    transOpData = operationData["other"]

    operations = {}
    outputLocationUri = writeOpData["params"]["table"]["storage"]["locationUri"]
    dataLayer = getLayerFromTableUri(outputLocationUri)
    outputTable = {
        "name": writeOpData["params"]["table"]["identifier"]["table"],
        "location_uri": outputLocationUri,
        "schema": "TBD",
        "layer": dataLayer,
        "database": writeOpData["params"]["table"]["identifier"]["database"]
    }
    writeOperation = {
        "name": writeOpData["extra"]["name"],
        "type": "WRITE_OP",
        "format": writeOpData["extra"]["destinationType"],
        "append": writeOpData["append"],
        "v_execution_plan": "TBD",
        "children": writeOpData["childIds"],
        "table": outputTable
    }

    operations[writeOpData["id"]] = writeOperation

    for opData in readOpsData:
        schema = json.dumps([columns[c] for c in opData["schema"]])
        locationUri = opData["params"]["table"]["storage"]["locationUri"]
        dataLayer = getLayerFromTableUri(outputLocationUri)
        table = {
            "name": opData["params"]["table"]["identifier"]["table"],
            "location_uri": locationUri,
            "schema": schema,
            "layer": dataLayer,
            "database": opData["params"]["table"]["identifier"]["database"],
        }
        readOperation = {
            "name": opData["extra"]["name"],
            "type": "READ_OP",
            "table": table
        }
        operations[opData["id"]] = readOperation

    for opData in transOpData:
        params = json.dumps(opData["params"])
        for dataType in dataTypes:
            params = params.replace(dataType["id"], dataType["name"])
        for attribute in attributes:
            params = params.replace(attribute["id"], attribute["name"])
        transOperation = {
            "name": opData["extra"]["name"],
            "type": "TRANS_OP",
            "param": params,
            "children": opData["childIds"]
        }
        if "schema" in opData:
            transOperation["schema"] = json.dumps([columns[s] for s in opData["schema"]])
        operations[opData["id"]] = transOperation

    return operations


def parseExecutionPlanFromExecutionEvents(payload):
    extra = payload["extra"]
    return {
        "read_metrics": json.dumps(extra["readMetrics"]),
        "write_metrics": json.dumps(extra["writeMetrics"]),
        "duration": extra["durationNs"]
    }


def getLayerFromTableUri(uri):
    if "-aggregated-" in uri:
        return "aggregated"
    elif "-curated-" in uri:
        return "curated"
    elif "-raw-" in uri:
        return "raw"
    else:
        return "unknown"
