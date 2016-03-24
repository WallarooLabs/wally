import collections
from copy import deepcopy
import hashlib

class Choices:
    def __init__(self, choices = None):
        self._choices = choices if choices is not None else []

    def size(self): return len(self._choices)

    def choices(self):
        return self._choices

    def targets(self):
        return [target for choice in self._choices for target in choice]

    def add_choice(self, choice):
        self._choices.append(choice)

    def has_target(self, target):
        for choice in self._choices:
            for t in choice:
                if t == target: return True
        return False

    def has_choice(self, choice):
        for c in self._choices:
            if c == choice: return True
        return False

    def clone(self):
        clones = deepcopy(self._choices)
        return Choices(clones)

    def __str__(self):
        out = "CHOICE: ["
        for choice in self._choices:
            out += "[" + ", ".join(list(map(lambda n: str(n), choice))) + "]"
        out += "]"
        return out


class FlowGraph:
    def __init__(self, node_count = 0):
        self._size = node_count
        self._out_es = []
        self._in_es = []
        self._nodes = []
        for i in range(self._size):
            self._out_es.append(Choices())
            self._in_es.append([])
            self._nodes.append({})

    def __repr__(self):
        return "%s(%r)" % (self.__class__, self.__dict__)

    def add_node(self, node):
        idx = self._size
        self._nodes.append(node)
        self._out_es.append(Choices())
        self._in_es.append([])
        self._size += 1
        return idx

    def update_node(self, n, key, val):
        self._nodes[n][key] = val

    def add_choice(self, origin, choice):
        # a "choice" is a list of targets (node indices)
        if not self._out_es[origin].has_choice(choice):
            self._out_es[origin].add_choice(choice)
            for target in choice:
                self._in_es[target].append(origin)

    def nodes(self):
        return self._nodes

    def choices_for(self, n):
        return self._out_es[n]

    def targets_for(self, n):
        return self.choices_for(n).targets()

    def has_one_choice_for(self, n):
        return self.choices_for(n).size() == 1

    def inputs_for(self, n):
        return self._in_es[n]

    def source(self):
        sources = self._sources()
        if len(sources) > 1:
            print('A topology can only have one source!')
            sys.exit()
        if len(sources) == 0:
            print('A topology must have a source!')
            sys.exit()
        return sources[0]

    def sink(self):
        sinks = self._sinks()
        if len(sinks) == 0:
            print('A topology must have a sink!')
            sys.exit()
        return sinks[0]

    def _sinks(self):
        sinks = []
        for i in range(self._size):
            if self._out_es[i].size() == 0:
                sinks.append(i)
        return sinks

    def _sources(self):
        sinks = []
        for i in range(self._size):
            if len(self._in_es[i]) == 0:
                sinks.append(i)
        return sinks

    def size(self):
        return self._size

    def clone(self):
        new_graph = FlowGraph()
        for i in range(self._size):
            node_copy = deepcopy(self._nodes[i])
            new_graph.add_node(node_copy)
        for j in range(self._size):
            choices_copy = self._out_es[j].clone()
            for choice in choices_copy.choices():
                new_graph.add_choice(j, choice)
        return new_graph

    def clone_choices_for(self, origin):
        choices = self._out_es[origin].clone()
        clones = []
        for choice in choices.choices():
            next_graph = self.clone()
            reduced_choice = Choices()
            reduced_choice.add_choice(choice)
            next_graph._out_es[origin] = reduced_choice
            clones.append(next_graph)
        return clones

    def predecessors_hash_for(self, node):
        total = 0
        next_level = self._in_es[node]
        seen = set(next_level)
        while len(next_level) > 0:
            for pred in next_level:
                t = self._nodes[pred]["type"]
                total += int(hashlib.sha1(t.encode()).hexdigest(), 16)
            last_level = deepcopy(next_level)
            next_level = []
            for this_pred in last_level:
                for next_pred in self._in_es[this_pred]:
                    if next_pred not in seen:
                        next_level.append(next_pred)
        return total

    def relabel(self, labels):
        # Takes a list of indices representing a relabeling of vertices
        #   The relabeling maps the list index (new label) to old label
        # Returns a graph that is relabeled according to this mapping
        if len(labels) != self._size: raise Exception("Wrong number of labels!")
        g = FlowGraph()
        for i in range(self._size):
            g.add_node(self._nodes[labels[i]])
        for j in range(self._size):
            for choice in self._out_es[labels[j]].choices():
                g.add_choice(j, choice)
        return g


class FlowGraphBuilder:
    def __init__(self):
        self._flow_graph = FlowGraph()
        self._id_lookup = {}

    def add_node(self, node):
        node_id = node["id"]
        idx = self._flow_graph.add_node(node)
        self._id_lookup[node_id] = idx

    def add_choice(self, origin, choice):
        idx = self._id_lookup[origin["id"]]
        ch = list(map(lambda n: self._id_lookup[n["id"]], choice))
        self._flow_graph.add_choice(idx, ch)

    def build(self):
        return self._flow_graph

def _flowgraph_to_set(graph, frontier, seen = None):
    branches = []
    # Seen vertices is used to handle cycles
    seen = seen if seen is not None else set([])
    while len(frontier) > 0:
        next = frontier[0]
        # Check for cycle
        if next in seen:
            frontier.pop()
            continue
        seen.add(next)
        if graph.has_one_choice_for(next):
            targets = graph.targets_for(next)
            for target in targets: frontier.append(target)
            frontier.popleft()
        else:
            new_graphs = graph.clone_choices_for(next)
            for g in new_graphs:
                branches = branches + _flowgraph_to_set(g, frontier)

    if len(branches) == 0:
        return [graph]
    else:
        return branches

def flowgraph_to_set(graph):
    # Takes a FlowGraph and returns a set of graphs without choices
    frontier = collections.deque([graph.source()])
    branches = _flowgraph_to_set(graph, frontier) # A list of graphs
    return branches

def sort_duplicate_types(list, graph):
    # Expects a list of (node_index, type_name) pairs sorted by type name
    # Checks for duplicate type names and sorts duplicates by predecessor hashes
    sorted_duplicates = []
    i = 0
    while i < len(list):
        cur = list[i]
        cur_type = cur[1]
        acc = [cur]
        for j in range(i + 1, len(list)):
            if list[j][1] == cur_type: acc.append(list[j])
            else: break
        if len(acc) > 1:
            with_hash = map(lambda pair: (pair[0], pair[1], graph.predecessors_hash_for(pair[0])), acc)
            ordered = sorted(with_hash, key=lambda triple: triple[2])
            for k in range(len(ordered)):
                sorted_duplicates.append((ordered[k][0], ordered[k][1]))
            i += len(acc)
        else:
            sorted_duplicates.append(cur)
            i += 1
    return sorted_duplicates

def zip_with_index(list):
    zipped = []
    for i in range(len(list)):
        zipped.append((i, list[i]))
    return zipped

def identity(x):
    return x

def sorted_indices(list, sorter=identity):
    # Sorts a list by a sorter and returns a list of (original_index, value) pairs
    zipped = zip_with_index(list)
    ordered = sorted(zipped, key=lambda pair: sorter(pair[1]))
    return map(lambda pair: (pair[0], sorter(pair[1])), ordered)

def sort_graph_vertices_by_type(graph):
    # Returns a list of indices sorted by type (ties are broken by iteratively hashing predecessor types)
    vertices = graph.nodes()
    indices = sorted_indices(vertices, lambda node: node["type"])
    return list(map(lambda pair: pair[0], sort_duplicate_types(list(indices), graph)))


## To check if a Traversal satisfies a Flow:
#      1) Convert the Flow FlowGraph to a set of graphs without choices
#      2) Relabel every graph in that set with the canonical labeling
#           a) You get the relabeling by running sort_graph_vertices_by_type()
#           b) Feed this result into graph.relabel()
#      3) Relabel the Traversal graph with the canonical labeling
#      4) Check if the relabeled Traversal graph is equal to any of the relabeled Flow graphs.




## TESTS

a = {
        "id": 1,
        "type": "A"
}

b = {
        "id": 2,
        "type": "B"
}

c = {
        "id": 3,
        "type": "C"
}

d = {
        "id": 4,
        "type": "D"
}

e = {
        "id": 5,
        "type": "E"
}

f = {
        "id": 6,
        "type": "F"
}

g = {
    "id": 7,
    "type": "G"
}

g2 = {
    "id": 8,
    "type": "G"
}

bldr = FlowGraphBuilder()
bldr.add_node(g2)
bldr.add_node(b)
bldr.add_node(a)
bldr.add_node(g)
bldr.add_node(d)
bldr.add_node(c)
bldr.add_node(e)
bldr.add_node(f)
# bldr.add_choice(a, [b, d])
# bldr.add_choice(b, [c])
# bldr.add_choice(b, [e])
# bldr.add_choice(c, [f])
# bldr.add_choice(d, [e])
# bldr.add_choice(e, [f, d])

bldr.add_choice(a, [b, c])
bldr.add_choice(b, [d])
bldr.add_choice(b, [g])
bldr.add_choice(c, [e])
bldr.add_choice(d, [f])
bldr.add_choice(d, [g])
bldr.add_choice(e, [f, c, g2])
bldr.add_choice(g, [f])
bldr.add_choice(g2, [f])

graph = bldr.build()
print("----OUTPUTS----")
# print(graph.choices_for(2))
# print(graph.size())
choices = graph.clone_choices_for(1)
# print(choices[0]._out_es[1])
# print(len(flowgraph_to_set(graph)))
# print(choices)
# print(len(choices))

initial_sort = sort_graph_vertices_by_type(graph)

print(initial_sort)

print(sort_graph_vertices_by_type(graph.relabel(initial_sort)))