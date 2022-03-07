from gremlin_python.process.graph_traversal import __
from gremlin_python.process.graph_traversal import GraphTraversal, GraphTraversalSource


def addVertex(t: GraphTraversalSource, label: str, properties: dict):
    t = t.addV(label)
    for k, v in properties.items():
        t = t.property(k, v)
    return t


def upsertVertex(vertex_traversal: GraphTraversal, label: str, properties: dict):
    create_traversal = __.addV(label)
    t = vertex_traversal.fold(). \
        coalesce(__.unfold(), create_traversal)

    for k, v in properties.items():
        t = t.property(k, v)
    return t


def updateProperties(g, v, properties):
    t = g.V(v)
    for (k, v) in properties.items():
        t = t.property(k, v)
    return t
