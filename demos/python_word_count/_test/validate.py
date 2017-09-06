import argparse
from json import loads


def pre_processor(decoded):
    totals = {}
    for c, v in decoded:
        totals[c] = v
    return totals

parser = argparse.ArgumentParser('Word count validator')
parser.add_argument('--output', type=argparse.FileType('rb'),
                    help="The output file of the application.")
parser.add_argument('--expected', type=argparse.FileType('r'),
                    help=("A file containing the expected final word count as "
                          "a JSON serialised dict."))
args = parser.parse_args()

decoded = []
while True:
    line = args.output.readline()
    if not line:
        break
    word, count_str = line.split(' => ')
    decoded.append((word, int(count_str)))
processed = pre_processor(decoded)

expected = loads(args.expected.read())
for k in expected.keys():
    s_key = str(k)
    expected[s_key] = expected.pop(k)

assert(expected == processed)
