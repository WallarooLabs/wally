prefix = 'digraph G {'
suffix = '}'
indent = '    '

def generate_dotfile(topology):
    dotfilename = topology.name + '.dot'
    file = open(dotfilename, 'w')
    file.truncate()

    file.write(prefix + '\n')

    # EDGES
    for node_id in range(topology.size()):
        origin_name = topology.get_node_option(node_id, 'name')
        spike_d = topology.get_node_option(node_id, "d")
        spike_p = topology.get_node_option(node_id, "p")
        label = spike_d + ' [p=' + spike_p + ']'
        if spike_d == 'pass':
            label = ''
        for t_id in topology.out_es[node_id]:
            terminus_name = topology.get_node_option(t_id, 'name')
            link = origin_name + ' -> ' + terminus_name + ' [ label = "' + label + '" ]'
            file.write(indent + link + ';\n')

    # NODE DEFINITIONS
    for node_id in range(topology.size()):
        name = topology.get_node_option(node_id, 'name')
        f = topology.get_node_option(node_id, 'f')
        label = name + '\\n<' + f + '>'
        df = name + ' [ label = "' + label + '" ]'
        file.write(indent + df + ';\n')

    file.write(suffix)
    file.close()