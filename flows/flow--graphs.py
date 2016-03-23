import collections
from copy import deepcopy

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
        self.out_es = []
        self.in_es = []
        self.nodes = []
        for i in range(self._size):
            self.out_es.append(Choices())
            self.in_es.append([])
            self.nodes.append({})

    def __repr__(self):
        return "%s(%r)" % (self.__class__, self.__dict__)

    def add_node(self, node):
        idx = self._size
        self.nodes.append(node)
        self.out_es.append(Choices())
        self.in_es.append([])
        self._size += 1
        return idx

    def update_node(self, n, key, val):
        self.nodes[n][key] = val

    def add_choice(self, origin, choice):
        # a "choice" is a list of targets (node indices)
        if not self.out_es[origin].has_choice(choice):
            self.out_es[origin].add_choice(choice)
            for target in choice:
                self.in_es[target].append(origin)

    def choices_for(self, n):
        return self.out_es[n]

    def targets_for(self, n):
        return self.choices_for(n).targets()

    def has_one_choice_for(self, n):
        return self.choices_for(n).size() == 1

    def inputs_for(self, n):
        return self.in_es[n]

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
            if self.out_es[i].size() == 0:
                sinks.append(i)
        return sinks

    def _sources(self):
        sinks = []
        for i in range(self._size):
            if len(self.in_es[i]) == 0:
                sinks.append(i)
        return sinks

    def size(self):
        return self._size

    def clone(self):
        new_graph = FlowGraph()
        for i in range(self._size):
            node_copy = deepcopy(self.nodes[i])
            new_graph.add_node(node_copy)
        for j in range(self._size):
            choices_copy = self.out_es[j].clone()
            for choice in choices_copy.choices():
                new_graph.add_choice(j, choice)
        return new_graph

    def clone_choices_for(self, origin):
        choices = self.out_es[origin].clone()
        clones = []
        for choice in choices.choices():
            next_graph = self.clone()
            reduced_choice = Choices()
            reduced_choice.add_choice(choice)
            next_graph.out_es[origin] = reduced_choice
            clones.append(next_graph)
        return clones


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

# Doesn't handle cycles
def _flowgraph_to_set(graph, frontier, seen = None):
    branches = []
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
    # frontier = frontier if frontier is not None else [graph.source()]
    frontier = collections.deque([graph.source()])
    branches = _flowgraph_to_set(graph, frontier) # A list of graphs
    return branches


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
        "type": "e"
}

f = {
        "id": 6,
        "type": "f"
}

g = {
    "id": 7,
    "type": "g"
}


bldr = FlowGraphBuilder()
bldr.add_node(a)
bldr.add_node(b)
bldr.add_node(c)
bldr.add_node(d)
bldr.add_node(e)
bldr.add_node(f)
bldr.add_node(g)
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
bldr.add_choice(e, [f, c])
bldr.add_choice(g, [f])

graph = bldr.build()
print("----OUTPUTS----")
print(graph.choices_for(2))
print(graph.size())
choices = graph.clone_choices_for(1)
print(choices[0].out_es[1])
print(len(flowgraph_to_set(graph)))
# print(choices)
# print(len(choices))