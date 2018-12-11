from metric import Metric
import struct
import unittest

class MetricParser(object):
    @classmethod
    def try_parse(cls, bytes):
        if bytes[0] == 3:
            return cls._parse_type_3_metric(bytes[1:])
        else:
            return None

    @classmethod
    def _parse_type_3_metric(cls, bytes):
        stream = BinaryReadStream(bytes)
        _event = stream.read_prefixed_string()
        _topic = stream.read_prefixed_string()
        _payload_size = stream.read_u32()
        _p_header = stream.read_u32()
        name = stream.read_prefixed_string()
        cat = stream.read_prefixed_string()
        worker = stream.read_prefixed_string()
        pipeline = stream.read_prefixed_string()
        id = stream.read_u16()
        # Latency bins number [0-64] (both ends inclusive)
        latencies = [stream.read_u64() for _ in range(0,65)]
        min = stream.read_u64()
        max = stream.read_u64()
        period = int(stream.read_u64() / 1000000000)
        timestamp = int(stream.read_u64() / 1000000000)
        return Metric(name, cat, worker, pipeline, id,
                      latencies, min, max, period, timestamp)


class BinaryReadStream(object):
    def __init__(self, binary_source):
        self._binary = binary_source
        self._offset = 0
    def read_u8(self): return self._read(">B")
    def read_u16(self): return self._read(">H")
    def read_u32(self): return self._read(">I")
    def read_u64(self): return self._read(">Q")
    def read_string(self, len): return self._read("{}s".format(len))
    def read_prefixed_string(self):
        return self.read_string(self.read_u32())
    def _read(self, format):
        (res,) = struct.unpack_from(format, self._binary,
                                    offset=self._offset)
        self._offset += struct.calcsize(format)
        return res


class Tests(unittest.TestCase):
    def test_example_payload_is_parsed(self):
        m = MetricParser.try_parse(self._example_payload())
        self.assertIsInstance(m, Metric)
        self.assertEqual(b"Decode Time in TCP Source", m.name)
        self.assertEqual(b"computation", m.category)
        self.assertEqual(b"initializer", m.worker)
        self.assertEqual(b"Alerts (windowed)", m.pipeline)
        self.assertEqual("1", m.id)
        self.assertListEqual(
            [0, 0, 0, 0, 0, 0, 57306, 505, 4,
             7, 0, 0, 2, 0, 17, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], m.latencies)
        self.assertEqual(14509, m.max)
        self.assertEqual(34, m.min)
        self.assertEqual(2, m.period)
        self.assertEqual(1544101820, m.timestamp)

    def _example_payload(_):
        return(bytearray(
            [3,0,0,0,7,109,101,116,114,105,99,115,
             0,0,0,23,109,101,116,114,105,99,115,58,65,108,101,114,
             116,115,95,119,105,110,100,111,119,101,100,
             0,0,2,126,0,0,3,18,0,0,0,25,68,101,99,111,100,101,32,84,105,
             109,101,32,105,110,32,84,67,80,32,83,111,117,114,99,101,
             0,0,0,11,99,111,109,112,117,116,97,116,105,111,110,
             0,0,0,11,105,110,105,116,105,97,108,105,122,101,114,
             0,0,0,17,65,108,101,114,116,115,32,40,119,105,110,100,
             111,119,101,100,
             41,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,223,218,0,0,
             0,0,0,0,1,249,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,17,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,56,173,
             0,0,0,0,119,53,148,0,21,109,192,108,158,34,88,0]))
