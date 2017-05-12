# Wallaroo Python Examples

In this section you will find the complete examples from the [Wallaroo Python](/book/python/intro.md) section, as well as some additional examples. Each example includes a README describing its purpose and how to set it up and run it.

To get set up for running examples, if you haven't already, refer to [Building a Python application](/book/python/building.md).

## Examples by Category

### Simple Stateless Applications

- [reverse](reverse/): a string reversing stream application.
- [celsius](celsius/): a Celsius-to-Fahrenheit stream application.

### Simple Stateful Applications

- [alphabet](alphabet/): a vote counting stream application.
- [sequence](sequence/): a stream application designed to demonstrate and test state management and state recovery. It keeps a window of the last 4 values it has seen as its state.

### Partitioned Stateful Applicatins

- [alphabet_partitioned](alphabet_partitioned/): a vote counting stream application using partitioning.
- [market_spread](market_spread/): a stream application that keeps a state for market data and checks trade orders against it in real time. This application uses state, partitioning, and two pipelines, each with its own source.
- [sequence_partitioned](sequence_partitioned/): a stream application designed to demonstrate and test state management and recovery. It keeps a window of the last 4 values seen as its state, partitioned modulo 2.


