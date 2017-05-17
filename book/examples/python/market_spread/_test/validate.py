import argparse
from struct import calcsize, unpack


parser = argparse.ArgumentParser('Alphabet validator')
parser.add_argument('--output', type=argparse.FileType('rb'),
                    help="The output file of the application")
parser.add_argument('--expected', type=argparse.FileType('rb'),
                    help=("A file containing the expected output"))
args = parser.parse_args()

header_fmt = '>I'
header_size = calcsize(header_fmt)

# Since order isn't identical in every run (multiple workers)
# we need to build a lookup set from expected, then ensure each
# received record is in it, and no expected records are left unmatched
received = set()
while True:
    header = args.output.read(header_size)
    if not header:
        break
    payload = args.output.read(unpack(header_fmt, header)[0])
    if not payload:
        break
    received.add(payload[:-8])

expected = set()
while True:
    header = args.expected.read(header_size)
    if not header:
        break
    payload = args.expected.read(unpack(header_fmt, header)[0])
    if not payload:
        break
    expected.add(payload[:-8])

in_ex_but_not_rec = expected - received
in_rec_but_not_ex = received - expected

try:
    assert(not in_ex_but_not_rec)
except:
    raise AssertionError("Not all expected records were received.")
try:
    assert(not in_rec_but_not_ex)
except:
    raise AssertionError("Not all received records were expected.")
