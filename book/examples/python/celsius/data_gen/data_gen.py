#!/usr/bin/env python2

import random
import struct


def generate_messages(num_messages):
    with open('celsius.msg', 'wb') as f:
        for x in xrange(num_messages):
            f.write(struct.pack('>If', 4, random.randrange(10000, _int=float)))


if __name__ == '__main__':
    import sys
    try:
        num_messages = int(sys.argv[1])
        generate_messages(num_messages)
    except:
        raise
