from io import BytesIO, BufferedReader
from struct import unpack


## Message Types
#   1: Connect
#   2: Join
#   3: Metrics

## Format types
#   U8: B
#   U16: H
#   U32: I
#   U64: Q
#   Text: <length>s
#   Array: <size><item1><item2>...

MSG_TYPES = {1: 'connect', 2: 'join', 3: 'metrics'}

def _s(n):
    return '{}s'.format(n)

class MetricsParser(object):
    def __init__(self):
        self.records = []
        self.data = {}

    def load_string_list(self, l):
        b = BytesIO()
        for s in l:
            b.write(s)
        b.seek(0)
        buf = BufferedReader(b)
        self.load_buffer(buf)

    def load_string(self, s):
        buf = BufferedReader(BytesIO(s))
        self.load_buffer(buf)

    def load_buffer(self, buf):
        while True:
            # read header
            header_bs = buf.read(4)
            if not header_bs:
                break
            header = unpack('>I', header_bs)[0]
            # message type
            msg_type_bs = buf.read(1)
            if not msg_type_bs:
                break
            msg_type = unpack('>B', msg_type_bs)[0]
            # payload
            if header:
                payload = buf.read(header-1)
            else:
                payload = ''
            self.records.append({'type': MSG_TYPES.get(msg_type, None),
                                 'payload': payload,
                                 'raw_type': msg_type})

    def parse(self):
        # populate self.data dict...
        for r in self.records:
            p = self.parse_record(r)
            if p['type'] == 'connect':
                continue
            elif p['type'] == 'join':
                topic = self.data.setdefault(p['topic'], {})
                worker = topic.setdefault(p['worker_name'], [])
                worker.append(('join',))
            elif p['type'] == 'metrics':
                topic = self.data.setdefault(p['topic'], {})
                worker = topic.setdefault(p['worker_name'], [])
                worker.append(('metrics', p))

    def parse_record(self, record):
        if record['type'] == 'connect':
            return self.parse_connect()
        elif record['type'] == 'join':
            return self.parse_join(record['payload'])
        elif record['type'] == 'metrics':
            return self.parse_metrics(record['payload'])
        else:
            raise MetricsParseError(
                "No known parsing logic for record {!r}".format(record))

    def parse_connect(self):
        return {'type': 'connect'}

    def parse_join(self, payload=''):
        buf = BufferedReader(BytesIO(payload))
        topic_size = unpack('>I', buf.read(4))[0]
        topic = unpack(_s(topic_size), buf.read(topic_size))[0]
        worker_name_size = unpack('>I', buf.read(4))[0]
        worker_name = unpack(_s(worker_name_size),
                             buf.read(worker_name_size))[0]
        return {'type': 'join', 'topic': topic, 'worker_name': worker_name}

    def parse_metrics(self, payload):
        buf = BufferedReader(BytesIO(payload))
        event_size = unpack('>I', buf.read(4))[0]
        event = unpack(_s(event_size), buf.read(event_size))[0]
        topic_size = unpack('>I', buf.read(4))[0]
        topic = unpack(_s(topic_size), buf.read(topic_size))[0]
        payload_size = unpack('>I', buf.read(4))[0]
        payload_header = unpack('>I', buf.read(4))[0]
        metric_name_size = unpack('>I', buf.read(4))[0]
        metric_name = unpack(_s(metric_name_size),
                             buf.read(metric_name_size))[0]
        metric_category_size = unpack('>I', buf.read(4))[0]
        metric_category = unpack(_s(metric_category_size),
                                 buf.read(metric_category_size))[0]
        worker_name_size = unpack('>I', buf.read(4))[0]
        worker_name = unpack(_s(worker_name_size),
                             buf.read(worker_name_size))[0]
        pipeline_name_size = unpack('>I', buf.read(4))[0]
        pipeline_name = unpack(_s(pipeline_name_size),
                               buf.read(pipeline_name_size))[0]
        ID = unpack('>H', buf.read(2))[0]
        latency_histogram = [unpack('>Q', buf.read(8))[0] for x in range(65)]
        max_latency = unpack('>Q', buf.read(8))[0]
        min_latency = unpack('>Q', buf.read(8))[0]
        duration = unpack('>Q', buf.read(8))[0]
        end_ts = unpack('>Q', buf.read(8))[0]

        return {
                'type': 'metrics',
                'event': event,
                'topic': topic,
                'payload_size': payload_size,
                'payload_header': payload_header,
                'metric_name': metric_name,
                'metric_category': metric_category,
                'worker_name': worker_name,
                'pipeline_name': pipeline_name,
                'id': ID,
                'latency_hist': latency_histogram,
                'total': sum(latency_histogram),
                'max_latency': max_latency,
                'min_latency': min_latency,
                'duration': duration,
                'end_ts': end_ts
                }
