# Robson

A process that writes Wallaroo Metric Stats to file, using the output of `merrick` `received-metrics.txt` to generate the stats.

Assuming that our `received-metrics.txt` is within the `merrick` directory, you would start Robson as follows:

```
./robson -i ../merrick/received-metrics.txt -o metrics-report-output.txt
```

The Robson metrics collector will attempt to parse the file, decoding any message that follows the Hub Protocol. It will store any message that belongs to the `metrics` event and the `start-to-end` or `computation` categories.

After storing the `metrics` messages, it will generate the stats and write to the output file path.
