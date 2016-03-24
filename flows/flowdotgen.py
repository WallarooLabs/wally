#!/usr/bin/env python3

prefix = 'digraph G {'
suffix = '}'
indent = '    '

def label_for(node, graph):
    type = graph.get_node(node)["type"]
    id = str(graph.get_node(node)["id"])
    return type + id

def generate_dotfile(graph, name="test"):
    dotfilename = name + '.dot'
    file = open(dotfilename, 'w')
    file.truncate()

    file.write(prefix + '\n')

    # EDGES
    for node_id in range(graph.size()):
        origin_name = label_for(node_id, graph)
        for t_id in graph._out_es[node_id]:
            terminus_name = label_for(t_id, graph)
            link = origin_name + ' -> ' + terminus_name
            file.write(indent + link + ';\n')

    # NODE DEFINITIONS
    for node_id in range(graph.size()):
        name = label_for(node_id, graph)
        file.write(indent + name + ';\n')

    file.write(suffix)
    file.close()