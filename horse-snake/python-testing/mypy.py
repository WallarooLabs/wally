class MyClass(object):
    def __init__(self):
        self.x = 0

def f():
    print "mypy f() has been run!"
    return None

def get_obj():
    print "getting MyClass"
    return MyClass()

def use_obj(x):
    print "using MyClass"
    print "x={}".format(x.x)
    return None

def get_application():
    return [("dothis", 1), ("dothat", 2)]
