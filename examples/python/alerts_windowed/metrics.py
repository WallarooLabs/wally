from hub_protocol import Metric, MetricParser
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
        .key_by(extract_name)
        # .to(wallaroo.range_windows(wallaroo.seconds(5))
        #     .over(TotalAggregation))
        .to(just_print_everything)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode))
    )

    return wallaroo.build_application("Metrics_windowed", pipeline)


@wallaroo.key_extractor
def extract_name(metric):
    return metric.name

@wallaroo.computation(name="print everything")
def just_print_everything(metric):
    # print(metric.worker, metric.pipeline, metric.timestamp)
    return metric

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_metrics(bs):
    return MetricParser.try_parse(bs)

@wallaroo.encoder
def encode(metric):
    m = "wallaroo.{}.{}.{} {} {}\n".format(
        sanitize_for_carbon(metric.pipeline),
        sanitize_for_carbon(metric.worker),
        sanitize_for_carbon(metric.name),
        sum(metric.latencies),
        metric.timestamp)
    return m


def sanitize_for_carbon(bytes):
    return re.sub('[^0-9A-Za-z]+', '_', bytes.decode()).lower()


