
# General notes on testing tools for Wallaroo

## Environment variables

The following environment variables are being introduced to provide
fine-grained control over aspects of Wallaroo applications as well
as their test scripts/programs.

### Environment variables: setsockopt buffering

The following naming convention is used for naming of environment variables
that are used to control use of the `setsockopt(2)` system call to adjust
OS socket buffer sizes for all TCP connections used by Wallaroo.

* If no environment variable is specified, then the OS default values for
  TCP socket buffering will be used.
* If an environment variable that matches the convention specified in the
  table below is found, then the variable's value will be used for
  `setsockopt(2)` calls for a category of TCP socket.

  The variable naming scheme is quasi-hierarchical. For example, calling
  `EnvironmentVar.get3("BASE", "FOO", "BAR")`
  will return the value of the first environment variable in
  the following list:
      1. BASE_FOO_BAR
      2. BASE_FOO
      3. BASE

  Component 1 | Component 2     | Component 3 | Use
  ------------|-----------------|-------------|-----
  INT_BUFSIZ | METRICS         | RCV         | Integration test Python TCP receiver for metrics data
  INT_BUFSIZ | SINK            | RCV         | Integration test Python TCP receiver for sink
  W_BUFSIZ   | BOUNDARY        | SND         | Wallaroo OutgoingBoundary send
  W_BUFSIZ   | DATA_CHANNEL    | RCV or SND  | Wallaroo DataChannel send/receive
  W_BUFSIZ   | METRICS         | SND         | Wallaroo ReconnectingMetricsSink send
  W_BUFSIZ   | TCP_SINK        | SND         | Wallaroo TCPSink send
  W_BUFSIZ   | TCP_SOURCE      | RCV         | Wallaroo TCPSink receive
  W_BUFSIZ   | CONTROL_CHANNEL | RCV or SND  | Wallaroo ControlChannelConnectNotifier receive/send
  W_BUFSIZ   | CONTROL_SENDER  | RCV or SND  | Wallaroo ControlSenderConnectNotifier receive/send

