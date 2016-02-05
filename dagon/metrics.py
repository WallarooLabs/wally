import numpy

percentiles = [50,75,90,99,99.9]

def print_throughput(r):
    print('\nTHROUGHPUT:')
    print(str(calc_throughput(r)) + ' msgs/sec')

def print_latency_histogram(s, r):
    print('\nLATENCY BY PERCENTILE (in microseconds):')
    histo = calc_latency_histogram(s, r)
    for p in percentiles:
        print(str(p) + ': ' + str(int(histo[p])))

def calc_throughput(r):
    count = len(r)

    start = r[0]['timestamp'] / 1000000
    end = r[count - 1]['timestamp'] / 1000000

    secs = end - start
    if secs == 0: secs = 1
    return int(count / secs)

def calc_latency_histogram(sent, rcvd):
    latencies = []
    histogram = {}
    if len(sent) != len(rcvd):
        print('Cannot calculate latency histogram because of mismatch between sent and received.')
        return ''

    for s, r in zip(sent, rcvd):
        sec = r['timestamp'] - s['timestamp']
        latencies.append(sec)

    data = numpy.array(latencies)
    for p in percentiles:
        histogram[p] = numpy.percentile(data, p)

    return histogram
