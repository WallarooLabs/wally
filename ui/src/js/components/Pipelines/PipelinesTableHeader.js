import React from 'react'
import MetricsTableHeader from "./Metrics/MetricsTableHeader"

export default class PipelinesTableHeader extends React.Component {
  shouldComponentUpdate(nextProps, nextState) {
    return false;
  }
  render() {
    return(
      <thead>
        <tr>
          <th>Pipeline</th>
          <th>Status</th>
          <th>Uptime</th>
          <th>Latency by Percentile Last 5 min (ms)</th>
          <th>Throughput Last 5 min (msg/sec)</th>
        </tr>
        <MetricsTableHeader />
      </thead>
    )
  }
}