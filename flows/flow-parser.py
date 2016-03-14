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

def new_walks():
    return [[]]

def new_multiwalks():
    return [[[]]]

def to_sets(tree, mwalks=new_multiwalks(), copies=False, mwalks_copy=''):
    root = tree.root()
    if is_seq(root):
        to_sets(tree.left(), mwalks, copies)
        to_sets(tree.right(), mwalks, copies)
        return mwalks
    elif is_fork(root):
        print("FORK")
        mwalks_copy = deepcopy(mwalks)
        to_sets(tree.left(), mwalks, copies)
        to_sets(tree.right(), mwalks, True, mwalks_copy)
        return mwalks
    elif is_choice(root):
        mwalks_copy = deepcopy(mwalks)
        to_sets(tree.left(), mwalks, copies)
        to_sets(tree.right(), mwalks_copy, copies)
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
                        mwalks[i].append(walk)
        return mwalks

formula = parse("A;((B;(D|E);G)||(C;F);G)")
# formula = parse("B;(C||D);(E|F)")
# formula = parse("B;C")

# print(parse("B|((C;D;F;(G||(H;I)))||E)"))

print(to_sets(formula))

