import unittest

class Metric(object):
    def __init__(self, name, cat, worker, pipeline, id,
                 latencies, min, max, period, ts):
        self.name = name
        self.category = cat
        self.worker = worker
        self.pipeline = pipeline
        self.id = str(int(id)) # dont need
        self.latencies = latencies
        self.min = min
        self.max = max
        self.period = period # dont need
        self.timestamp = ts  # send to graphite


class AggregatedMetric(object):
    @classmethod
    def identity(cls):
        return cls(min=float('Inf'),
                   max=float('-Inf'),
                   latencies=[0 for _ in range(65)])

    def __init__(self, min, max, latencies, timestamp=-1):
        self.min = min
        self.max = max
        self.latencies = latencies
        self.timestamp = timestamp

    def add(self, other): # other : (AggregatedMetric | Metric)
        self.min = min(self.min, other.min)
        self.max = max(self.max, other.max)
        self.latencies = [x+y for (x,y) in
                          zip(self.latencies, other.latencies)]
        self.timestamp = max(self.timestamp, other.timestamp)
        return self


class AggregatedMetricTests(unittest.TestCase):
    def test_identity_plus_identity_is_identity_on_min(self):
        a1 = AggregatedMetric.identity()
        m1 = a1.min
        a1.add(AggregatedMetric.identity())
        self.assertEqual(a1.min, m1)

    def test_identity_plus_identity_is_identity_on_max(self):
        a1 = AggregatedMetric.identity()
        m1 = a1.max
        a1.add(AggregatedMetric.identity())
        self.assertEqual(a1.max, m1)

    def test_identity_latencies_add_to_array_of_zeroes(self):
        a1 = AggregatedMetric.identity()
        l1 = a1.latencies
        a1.add(AggregatedMetric.identity())
        self.assertEqual(a1.latencies, l1)
        self.assertListEqual(a1.latencies, [0 for _ in range(65)])

    def test_identity_plus_a_is_a_on_min(self):
        a1 = AggregatedMetric.identity()
        m1 = a1.min
        a1.add(AggregatedMetric(min=1, max=100, latencies=[]))
        self.assertEqual(a1.min, 1)

    def test_identity_plus_a_is_a_on_max(self):
        a1 = AggregatedMetric.identity()
        m1 = a1.max
        a1.add(AggregatedMetric(min=1, max=100, latencies=[]))
        self.assertEqual(a1.max, 100)

    def test_identity_plus_a_is_a_on_max(self):
        a1 = AggregatedMetric.identity()
        m1 = a1.max
        a1.add(AggregatedMetric(min=1, max=100, latencies=[]))
        self.assertEqual(a1.max, 100)

    def test_identity_plus_a_is_a_on_latencies(self):
        a1 = AggregatedMetric.identity()
        a1.add(AggregatedMetric(min=1, max=1,
                                latencies=[i for i in range(65)]))

        self.assertListEqual(a1.latencies, [i for i in range(65)])

    def test_add_on_min_takes_lower_value(self):
        a1 = AggregatedMetric(min=1, max=10, latencies=[])
        a2 = AggregatedMetric(min=2, max=10, latencies=[])
        a1.add(a2)

        self.assertEqual(a1.min, 1)

    def test_add_on_max_takes_higher_value(self):
        a1 = AggregatedMetric(min=1, max=10, latencies=[])
        a2 = AggregatedMetric(min=2, max=20, latencies=[])
        a1.add(a2)

        self.assertEqual(a1.max, 20)

    def test_add_on_latencies_adds_values(self):
        a1 = AggregatedMetric(min=1, max=10,
                              latencies=[ i for i in range(65)])
        a2 = AggregatedMetric(min=1, max=10,
                              latencies=[ i for i in range(65)])
        a1.add(a2)

        self.assertListEqual(a1.latencies, [i*2 for i in range(65)])

    def test_default_timestamp_is_negative_one(self):
        # negative one tells carbon to use ingestion time
        a1 = AggregatedMetric.identity()

        self.assertEqual(a1.timestamp, -1)

    def test_add_on_timestamp_takes_max(self):
        # negative one tells carbon to use ingestion time
        a1 = AggregatedMetric(min=1, max=10, latencies=[], timestamp=1)
        a2 = AggregatedMetric(min=1, max=10, latencies=[], timestamp=2)
        a1.add(a2)

        self.assertEqual(a1.timestamp, 2)
