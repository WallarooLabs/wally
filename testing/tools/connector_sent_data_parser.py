import struct
import sys

try:
    import wallaroo.experimental.connector_wire_messages as cwm
except:
    print("Couldn't import wallaroo.experimental.connector_wire_messages. Please ensure that machida/lib/ is on your PYTHONPATH")


filename = sys.argv[1]

print("parsing file: {}".format(filename))

f = open(filename, 'rb')
o = open('out.txt', 'wt')

while True:
    hb = f.read(4)
    if not hb:
        break
    h = struct.unpack('>I', hb)[0]
    b = f.read(h)
    if not b:
        break
    m = cwm.Frame.decode(b)
    o.write("{}\n".format(m))

print("Parsed sender data written to 'out.txt'")
