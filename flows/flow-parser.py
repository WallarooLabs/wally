from copy import deepcopy

class Tree:
    def __init__(self, root, left, right):
        self._root = root
        self._left = left
        self._right = right

    def root(self):
        return self._root

    def left(self):
        return self._left

    def right(self):
        return self._right

    def __str__(self):
        if self._left == None and self._right == None:
            return "[" + self._root + "]"
        return '[' + self._root + ', ' + str(self._left) + ', ' + str(self._right) + ']'


operators = [';', '||', '|']

def is_worker(str):
    return str[0].isalpha()

def is_op(str):
    one = str[0]
    two = str[0:2]
    return one in operators or two in operators

def is_seq(str):
    return str == ";"

def is_fork(str):
    return str == "||"

def is_choice(str):
    return str == "|"

def get_op(str):
    if str[0:2] == '||':
        return ['||', str[2:len(str)]]
    else:
        return [str[0], str[1:len(str)]]

def get_paren_block(str):
    if str[0] != '(':
        raise Exception("No starting left paren!")
    str = str[1:len(str)]
    left_count = 1
    right_count = 0
    block = []
    while True:
        if len(str) == 0:
            raise Exception("No matching right paren!")
        elif str[0] == '(':
            block.append(str[0])
            left_count = left_count + 1
            str = str[1:len(str)]
        elif str[0] == ')':
            right_count = right_count + 1
            if left_count == right_count:
                return [''.join(block), str[1:len(str)]]
            else:
                block.append(str[0])
                str = str[1:len(str)]
        else:
            block.append(str[0])
            str = str[1:len(str)]

def parse(str):
    if str[0].isalpha():
        if len(str) == 1:
            return Tree(str[0], None, None)
        else:
            op,rest = get_op(str[1:len(str)])
            return Tree(op, Tree(str[0], None, None), parse(rest))
    elif str[0] == '(':
        left,p_rest = get_paren_block(str)
        if p_rest == '':
            return parse(left)
        else:
            op,rest = get_op(p_rest)
            return Tree(op, parse(left), parse(rest))
    else:
        raise Exception("Something went wrong! Invalid format for " + str)


def new_mwalks(): return [[[]]]

class Flow:
    def __init__(self, mwalks=new_mwalks()):
        self._mwalks = mwalks

    def add_step(self, step):
        for mwalk in self._mwalks:
            for walk in mwalk:
                walk.append(step)

    def append(self, flow):
        updated_mwalks = []
        for fmwalk in flow._mwalks:
            for mwalk in self._mwalks:
                next_mwalk = []
                for fwalk in fmwalk:
                    for i in range(0, len(mwalk)):
                        walk_copy = deepcopy(mwalk[i])
                        for fstep in fwalk:
                            walk_copy.append(fstep)
                        next_mwalk.append(walk_copy)
                updated_mwalks.append(next_mwalk)
        self._mwalks = updated_mwalks
        return self

    def merge_choice(self, flow):
        for fmwalk in flow._mwalks:
            self._mwalks.append(fmwalk)

    def merge_fork(self, flow):
        updated_mwalks = []
        for mwalk in self._mwalks:
            for fmwalk in flow._mwalks:
                mwalk_copy = deepcopy(mwalk)
                for fwalk in fmwalk:
                    mwalk_copy.append(fwalk)
                updated_mwalks.append(mwalk_copy)
        self._mwalks = updated_mwalks

    def to_lists(self):
        return self._mwalks

    def __str__(self):
        return "FLOW:" + str(self._mwalks)


def to_flow(tree):
    root = tree.root()
    if is_seq(root):
        left = to_flow(tree.left())
        right = to_flow(tree.right())
        left.append(right)
        return left

    elif is_fork(root):
        left = to_flow(tree.left())
        right = to_flow(tree.right())
        left.merge_fork(right)
        return left

    elif is_choice(root):
        left = to_flow(tree.left())
        right = to_flow(tree.right())
        left.merge_choice(right)
        return left
    else:
        node = Flow([[[]]])
        node.add_step(root)
        return node

def to_tla_sets(mwalks):
    sets = []
    for mwalk in mwalks:
        next_walks = []
        for walk in mwalk:
            next_walks.append('<' + ', '.join(walk) + '>')
        sets.append('{' + ', '.join(next_walks) + '}')
    return '{' + ', '.join(sets) + '}'



def get_lists_for(tree):
    return to_flow(tree).to_lists()

# formula = "A;((B;(D|E);G)||(C;F;H))"

# formula = "A;((B;(D|E);G)||(F;H))"
# formula = "A;(G||(F;H))"
# formula = "B;(C||D);(E||F)"
# formula = "A;((B|(C|D))||((E||F);(G|H)))"
# formula = "A;((C|D)||((E||F);(G|H)))"
# formula = "A;(C||(E||F))"
# formula = "A;(C||(E|F))"
# formula = "A;(E|F)"
# formula = "B;(C|D);G;(E|F)"
# formula = "B;(C|D);G"
# formula = "B;(C|D);(E||F)"
formula = "B;((C|D)||(E||F))"
# formula = "B;C"
# formula = "B;C;D"
# formula = "B;C;D;E"
# formula = "B;(C||D)"
# print(formula)
# print("B|((C;D;F;(G||(H;I)))||E)")
# formula = "A"

print("FLOW:")
print(formula)
AST = parse(formula)
lists = get_lists_for(AST)
print("")
print("OUTPUT (as lists):")
print(lists)
print("")
print("OUTPUT (in TLA+ notation):")
print(to_tla_sets(lists))
print("")


