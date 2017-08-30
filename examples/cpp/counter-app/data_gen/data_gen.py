#!/usr/bin/env python2

import random
import struct

fmt = '>HH{}'.format(10*'L')
def generate_messages(num_messages):
    with open('numbers.msg', 'wb') as f:
        for x in xrange(num_messages):
            f.write(struct.pack(fmt, 42, 10,
                                *[random.randrange(1000000) for x in
                                  xrange(10)]))


if __name__ == '__main__':
    import sys
    try:
        num_messages = int(sys.argv[1])
        generate_messages(num_messages)
    except:
        raise
