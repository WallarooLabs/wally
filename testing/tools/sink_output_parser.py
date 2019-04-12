import struct
import sys


filename = sys.argv[1]

print("parsing file: {}".format(filename))

f = open(filename, 'rb')
if len(sys.argv) == 3:
    output_file = sys.argv[2]
else:
    output_file = 'out.txt'
o = open(output_file, 'wt')

while True:
    hb = f.read(4)
    if not hb:
        break
    h = struct.unpack('>I', hb)[0]
    b = f.read(h)
    if not b:
        break
    o.write("{}\n".format(b.decode()))

print("Parsed sink output {} and saved it to {}".format(
    filename, output_file))
