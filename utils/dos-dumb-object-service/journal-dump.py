#!/usr/bin/env python2

from optparse import OptionParser
import os
from struct import unpack
import sys

parser = OptionParser(usage='%prog [-v] [-n] /path/to/journal/file')
parser.add_option('-n', default=False, dest='no_output', action='store_true',
    help='Do not write journal data to files in the local file system')
parser.add_option('-v', default=False, dest='verbose', action='store_true',
    help='Verbose output of each entry in the journal file')
(options, args) = parser.parse_args()

try:
    f = open(args[0], 'r')
except e:
    print 'cannot open %s: %s' % (args[0], e)
    sys.exit(1)
    
while True:
    b = f.read(4)
    if len(b) != 4:
        break

    (num_bytes,) = unpack('>L', b)
    # print "DBG: num_bytes = %d" % num_bytes
    b = f.read(num_bytes)
    if len(b) != num_bytes:
        print 'Error: wanted %d bytes but got %d instead' % (num_bytes, len(b))
        sys.exit(1)
    offset = 12
    (version, op, num_int, num_string, tag,) = unpack('>BBBBQ', b[0:offset])

    ints = []
    strings_len = []
    strings = []

    for i in range(num_int):
        (n,) = unpack('>Q', b[offset+(8*i) : offset+(8*i) + 8])
        ints.append(n)
    offset += (num_int * 8)

    for i in range(num_string):
        (n,) = unpack('>Q', b[offset+(8*i) : offset+(8*i) + 8])
        strings_len.append(n)
    offset += (num_string * 8)
    b = b[offset:]
    for i in range(num_string):
        strings.append(b[0:strings_len[i]])
        b = b[strings_len[i]:]

    if options.verbose:
        print 'version=%d op=%d tag=%d ints=%s strings=%s' % (version, op, tag, ints, strings)

    if not options.no_output:
        if op == 0:
            # set_length
            output_file = strings[0]
            offset = ints[0]
            if not os.access("myfile", os.W_OK):
                # Create the file
                if options.verbose: print 'DBG: set_length %s touch' % (output_file)
                with open(output_file, 'a') as of:
                    True
            with open(output_file, 'r+') as of:
                try:
                    if options.verbose: print 'DBG: set_length %s %d' % (output_file, offset)
                    of.truncate(offset)
                except e:
                    print 'I/O ERROR: truncate: %s %d: %s' % (output_file, offset, e)
                    exit(1)
        if op == 1:
            # writev
            output_file = strings[0]
            data = strings[1]
            offset = ints[0]
            if not os.access("myfile", os.W_OK):
                # Create the file
                if options.verbose: print 'DBG: writev %s touch' % (output_file)
                with open(output_file, 'a') as of:
                    True
            if options.verbose: print 'DBG: writev %s %d %d bytes' % (output_file, offset, len(data))
            with open(output_file, 'r+') as of:
                try:
                    if options.verbose: print 'DBG: set_length %s %d' % (output_file, offset)
                    of.seek(offset)
                    of.write(data)
                except e:
                    print 'I/O ERROR: writev: %s %d: %s' % (output_file, offset, e)
                    exit(1)
        if op == 2:
            # remove
            output_file = strings[0]
            if options.verbose: print 'DBG: remove %s' % (output_file)
            try:
                os.unlink(output_file)
            except OSError as e:
                print 'NOTICE: unlink: file %s does not exist' % (output_file)
            except Exception as e:
                print 'I/O ERROR: unlink: %s: %s' % (output_file, e)
                exit(1)

print 'EOF'
sys.exit(0)
