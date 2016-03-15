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

def new_multiwalks():
    return [[[]]]

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

    def clone_walks(self):
        clones = deepcopy(self._walks)
        for walk in clones:
            mwalk.append(walk)
        return Prefix(mwalk, clones)

def new_prefixes():
    return []

class Prefixes:
    def __init__(self, pfixes=new_prefixes()):
        self._pfixes = pfixes

    def clone(self):
        new_list = []
        for pfix in self._pfixes:
            clone = pfix.clone_walks()
            new_list.append(pfix)
            new_list.append(clone)
        return Prefixes(new_list)


def to_sets(tree, mwalks=new_multiwalks(), copies=False, choices=Choices(), mwalks_copy=new_multiwalks()):
    root = tree.root()
    if is_seq(root):
        to_sets(tree.left(), mwalks, copies, choices, mwalks_copy)
        to_sets(tree.right(), mwalks, copies, choices, mwalks_copy)
        return mwalks
    elif is_fork(root):
        backup = []
        cur_choices = choices.count()
        # Make deep copy of current prefixes for right descent
        # If there's already a copy, make a backup for right descent
        if mwalks_copy == [[[]]]:
            mwalks_copy = deepcopy(mwalks)
        else:
            backup = deepcopy(mwalks_copy)

        to_sets(tree.left(), mwalks, copies, choices, mwalks_copy)

        # Copy is discharged after being mutated on left descent
        # Restore to backup
        if backup != []:
            mwalks_copy = backup

        # If there are unhandled choices, duplicate the multiwalks
        # an equal number of times in order to add right fork
        # results to those multiwalks as well
        if cur_choices < choices.count():
            diff = choices.count() - cur_choices
            while diff > 0:
                new_copy = deepcopy(mwalks_copy)
                for walk in new_copy:
                    mwalks_copy.append(walk)
                diff = diff - 1
        # Add the copied walks back to mwalks so when they're
        # updated they're also updated in mwalks
        for i in range(0, len(mwalks_copy)):
            for walk in mwalks_copy[i]:
                mwalks[i].append(walk)
        to_sets(tree.right(), mwalks, True, choices, mwalks_copy)
        return mwalks
    elif is_choice(root):
        choices.inc()
        mwalks_copy = deepcopy(mwalks)
        to_sets(tree.left(), mwalks, copies, choices, mwalks_copy)
        to_sets(tree.right(), mwalks_copy, copies, choices, mwalks_copy)
        for mwalk in mwalks_copy:
            mwalks.append(mwalk)
        return mwalks
    else:
        if root != None:
            if not copies:
                for mwalk in mwalks:
                    for walk in mwalk:
                        walk.append(root)
            else:
                for i in range(0, len(mwalks_copy)):
                    for walk in mwalks_copy[i]:
                        walk.append(root)
        return mwalks

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
# formula = parse("B;C")
# print(formula)
# print(parse("B|((C;D;F;(G||(H;I)))||E)"))

print(to_sets(formula))


