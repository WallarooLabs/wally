from copy import deepcopy

class Tree:
    def __init__(self, root, left, right):
        self._root = root
        self._left = left
        self._right = right

    def update_root(self, root):
        self._root = root

    def update_left(self, left):
        self._left = left

    def update_right(self, right):
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


class Choices:
    def __init__(self):
        self._count = 0

    def inc(self):
        self._count = self._count + 1

    def dec(self):
        self._count = self._count - 1

    def count(self):
        return self._count

class Prefix:
    def __init__(self, mwalk, walks_to_update):
        self._mwalk = mwalk
        self._walks = walks_to_update

    def add_step(self, step):
        for walk in self._walks:
            walk.append(step)

    def clone(self):
        clone = deepcopy(self._mwalk)
        return Prefix(clone, clone)

    def clone_walks(self):
        clones = deepcopy(self._walks)
        # for walk in clones:
        #     mwalk.append(walk)
        return Prefix(self._mwalk, clones)

    def update_mwalk(self):
        for i in range(0, len(self._walks)):
            walk = self._walks[i]
            self._mwalk.append(walk)

    def update(self):
        self._mwalk = self._walks

    def to_set(self):
        return self._walks

    def is_not(self, pfix):
        return self._mwalk != pfix._mwalk

    def __str__(self):
        return "Prefix:" + str(self._mwalk)

def new_prefixes():
    mwalks = [[]]
    return [Prefix(mwalks, mwalks)]

class Prefixes:
    def __init__(self, pfixes=new_prefixes()):
        self._pfixes = pfixes

    def pfixes(self):
        return self._pfixes

    def add_pfix(self, pfix):
        self._pfixes.append(pfix)

    def add_step(self, step):
        for pfix in self._pfixes:
            pfix.add_step(step)

    def add_pfixes_from(self, other_pfixes):
        for pfix in other_pfixes.pfixes():
            self._pfixes.append(pfix)

    def clone(self):
        new_list = []
        for pfix in self._pfixes:
            clone = pfix.clone()
            new_list.append(clone)
        return Prefixes(new_list)

    def clone_walks(self):
        clones = list(map(lambda p: p.clone_walks(), self._pfixes))
        return Prefixes(clones)

    def update_mwalks(self):
        for pfix in self._pfixes:
            pfix.update_mwalk()

    def update(self):
        for pfix in self._pfixes:
            pfix.update()

    def to_sets(self):
        return map(lambda p: p.to_set(), self._pfixes)


def to_prefixes(tree, pfixes=Prefixes(), pfixes_copy=None, choices=Choices()):
    if not pfixes_copy:
        pfixes_copy = pfixes

    root = tree.root()

    if is_seq(root):
        to_prefixes(tree.left(), pfixes, pfixes_copy, choices)
        to_prefixes(tree.right(), pfixes, pfixes_copy, choices)
        return pfixes
    elif is_fork(root):
        cur_choice = choices.count()
        backup_pfixes = pfixes_copy.clone_walks()

        to_prefixes(tree.left(), pfixes, pfixes_copy, choices)

        if cur_choice < choices.count():
            for i in range(0, len(backup_pfixes.pfixes())):
                bpfix = backup_pfixes.pfixes()[i]
                for pfix in pfixes.pfixes():
                    if bpfix.is_not(pfix):
                        backup_pfixes.add_pfix(pfix)

        to_prefixes(tree.right(), pfixes, backup_pfixes, choices)
        backup_pfixes.update_mwalks()
        # print("YO")
        # for pfix in pfixes.pfixes():
        #     print(pfix)
        return pfixes
    elif is_choice(root):
        choices.inc()
        backup_pfixes = pfixes_copy.clone()
        to_prefixes(tree.left(), pfixes, pfixes_copy, choices)
        to_prefixes(tree.right(), backup_pfixes, backup_pfixes, choices)

        pfixes.add_pfixes_from(backup_pfixes)
        return pfixes
    else:
        if root != None:
            pfixes_copy.add_step(root)

        return pfixes

def prefixify(tree):
    pfixes = Prefixes()
    return to_prefixes(tree, pfixes)

def get_sets_for(tree):
    prefixes = prefixify(tree)
    print("RESULTS:")
    for pfix in prefixes.pfixes():
        print(pfix)
    return prefixes.to_sets()

# formula = parse("A;((B;(D|E);G)||(C;F;H))")

# formula = parse("A;((B;(D|E);G)||(F;H))")
# formula = parse("A;(G||(F;H))")
# formula = parse("B;(C||D);(E|F)")
# formula = parse("A;((B|(C|D))||((E||F);(G|H)))")
# formula = parse("A;((C|D)||((E||F);(G|H)))")
# formula = parse("A;(C||(E||F))")
formula = parse("A;(C||(E|F))")
# formula = parse("A;(E|F)")
# formula = parse("B;(C|D);(E||F)")
# formula = parse("B;((C|D)||(E||F))")
# formula = parse("B;C;D")
# formula = parse("B;C;D;E")
# formula = parse("B;(C||D)")
# print(formula)
# print(parse("B|((C;D;F;(G||(H;I)))||E)"))
# formula = parse("A")

print(get_sets_for(formula))


