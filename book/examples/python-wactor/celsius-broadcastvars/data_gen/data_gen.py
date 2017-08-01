#!/usr/bin/env python2

import random
import struct


def generate_messages(num_messages):
    with open('celsius.msg', 'wb') as f:
        for x in xrange(num_messages):
            f.write(struct.pack('>Lf', 4, random.uniform(0, 10000)))


if __name__ == '__main__':
    import sys
    try:
        num_messages = int(sys.argv[1])
        generate_messages(num_messages)
    except:
        raise
