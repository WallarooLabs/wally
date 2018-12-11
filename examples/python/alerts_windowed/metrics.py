from hub_protocol import MetricParser
from metric import Metric, AggregatedMetric
import re
import struct
import wallaroo

def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    incoming_metrics = wallaroo.source("Incoming metrics",
                         wallaroo.TCPSourceConfig(in_host, in_port,
                                                  decode_metrics,
                                                  parallelism=20))

    pipeline = (incoming_metrics
        .key_by(metric_key)
        .to(wallaroo.range_windows(wallaroo.seconds(10))
            .with_slide(wallaroo.seconds(2))
            .over(MetricsAggregation()))
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode))
    )
    return wallaroo.build_application("Metrics_windowed", pipeline)


class MetricsAggregation(wallaroo.Aggregation):
    def initial_accumulator(self):
        return AggregatedMetric.identity()

    def update(self, metric, agg):
        agg.add(metric)

    def combine(self, m1, m2):
        return AggregatedMetric.identity().add(m1).add(m2)

    def output(self, key, agg):
        return (key, agg.min, agg.max, sum(agg.latencies), agg.timestamp)

@wallaroo.key_extractor
def metric_key(metric):
    return (u".".join(map(sanitize_for_carbon,
                          [metric.category, metric.pipeline,
                           metric.worker, metric.name])))

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_metrics(bs):
    return MetricParser.try_parse(bs)

@wallaroo.encoder
def encode(aggregated_tuple):
    (key, min, max, throughput, ts) = aggregated_tuple
    min_metric = "wallaroo.{}.min {} {}\n".format(key, min, ts)
    max_metric = "wallaroo.{}.max {} {}\n".format(key, max, ts)
    tput_metric = "wallaroo.{}.throughput {} {}\n".\
      format(key, throughput, ts)
    return "".join((min_metric, max_metric, tput_metric))

def sanitize_for_carbon(bytes):
    return re.sub('[^0-9A-Za-z]+', '_', bytes.decode()).lower()
