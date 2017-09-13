# Testing Restarting a Wallaroo Worker

## Description

Wallaroo workers should be able to rejoin an application cluster even when resilience isn't enabled. To do this, they need to be able to identify the correct connection parameters, and then connect to the appropriate workers based on the topology configuration.
Since recovery tests this component as well, we do not need to run this test with recovery.

### Setting Up for the Test

1. build `testing/correctness/apps/sequence_window` with debug, but without any other options.
2. create a `res-data` directory in the `testing/correctness/apps/sequence_window` directory

### Running the Test

1. Start a sink
2. Start initializer
3. Start worker
4. Send some data
5. Kill worker
6. Observe worker channel is MUTED on initializer
7. Restart worker
8. Observe worker rejoins successfully and worker channel is UNMUTED on initializer
9. Observe data flows through the worker as well as initializer
10. Kill initializer
11. Restart initializer
12. Restart sender (unless it is reconectable)
12. Observe that data flows through both initializer and worker and all the way to the sink.
