# Wallaroo Python Examples

In this section you will find the complete examples from the [Wallaroo Python](https://docs.wallaroolabs.com/python-tutorial/) section, as well as some additional examples. Each example includes a README describing its purpose and how to set it up and run it.

To get set up for running examples, if you haven't already, refer to [Choosing an Installation Option for Wallaroo](https://docs.wallaroolabs.com/python-installation/).

## Examples by Category

### Simple Stateless Applications

- [alerts_stateless](alerts_stateless/): a stateless transaction alerts stream application.
- [celsius-kafka](celsius-kafka/): A Celsius-to-Fahrenheit stream application using a Kafka source and a Kafka sink (instead of a TCP source and a TCP sink).

### Stateful Applications

- [alerts_stateful](alerts_stateful/): a stateful transaction alerts stream application.
- [alphabet](alphabet/): a vote counting stream application.
- [market_spread](market_spread/): a stream application that keeps a state for market data and checks trade orders against it in real time. This application uses state, partitioning, and two source streams.
- [word_count](word_count/): an application that counts the number of occurences of words in a stream
