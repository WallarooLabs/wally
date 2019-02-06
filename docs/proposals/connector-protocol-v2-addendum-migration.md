# Wallaroo Connector Protocol Addendum: Migration

**STATUS: draft**

This addednum proposes changes to the protocol to accommodate migration as a cooperative process between a Wallaroo worker and the source connector.

## Overview

In order to accommdate migration, the source connector will need two additional properties:
1. the ability to connect to a _new_ address
2. new behaviour to execute a migration

Wallaroo will need the following:
1. knowledge of the new source address at the old source worker
2. a protocol for performing a migration
3. the ability to migrate the source's state

The protocol needs two new messages:
1. `MIGRATE(new_address)`: Wallaroo -> Connector
2. `MIGRATION_ACK`: Connector -> Wallaroo


## Protocol State Machine

Each connection must follow the following state machine definition.

```
      +-------------------+----------------------------+
      |                   |                            |
 +-----------+       +-----------+     +-----------+   |
 | Connected +------>| Handshake +---->| Streaming |---+
 +-----------+       +-----------+     +-----------+   |
  ^      |                |                  |         |
  |      |                +--------+         |         |
  |      |                V        |         |         V
  |      |            +--------+   |         |   +-----------+
  |      +----------> | Error  | <-----------+---| Migrating |
  |      |            +--------+   |         |   +-----------+
  |      |                |        |         |         |
  |      |                V        V         |         |
  |      |       +-------------------+       |         |
  |      +------>+  Disconnected     |<------+---------+
  |              +-------------------+                 |
  |                                                    |
  +----------------------------------------------------+
```

In the connected state the following frame types are valid:

    - HELLO: Connector -> Worker (next state = handshake)
    - ERROR: * -> * (next state = error)
    - MIGRATE: Worker -> Connector

In the handshake state the following frame types are valid:

    - OK: Worker -> Connector (next state = streaming)
    - ERROR: * -> * (next state = error)
    - MIGRATE: Worker -> Connector (next state = migrating)

In the streaming state the following frame types are valid:

   - NOFITY: Connector -> Worker
   - NOTIFY_ACK: Worker -> Connector
   - MESSAGE: Connector -> Worker
   - ACK: Worker -> Connector
   - RESTART: Worker -> Connector
   - ERROR: * -> * (next state = error)
   - MIGRATE: Worker -> Connector (next state = migrating)

In the migrating state, the following frame types are valid:
  - MIGRATE_OK: Connector -> Worker (next state = connected)
  - ERROR: * -> * (next state = error)


## Migration Protocol

In order to accomplish a migration, the following sequence of event needs to occur:

| order | Connector | Worker |  Notes |
| - | - | - | - |
| 0 | Connect | - | Connector is in one of {Connected, Handshake, Steaming} |
| 1 | - | send MIGRATE | This message contains information about the new target address |
| 2 | close all streams | - | - |
| 3 | send EOS for all streams | - | - |
| 4 | - | checkpoint all streams | - |
| 5 | - | migrate source state to new worker | - |
| 6 | - | Ack all streams | - |
| 7 | connect to new target address | - | Old connection is still open |
| 8 | Handshake on new address | - | Old connection is still open |
| 9 | send MIGRATION_ACK | - | Send this on old connection |
| 10 | - | Worker closes connection, completes shut down | - |
| 11 | resume streaming | - | on new connection; Send NOTIFYs, etc. | - |

### Notes
- The Connector needs to connect to the new source before closing the old one
- In the case of ERROR during this process, the connector will have enough information to reach out to BOTH the old and the new source addresses... IF attempting to reconnect after an error or loss of connection, the Connector may connect to either, and if no reponse, try the other one. If both addresse are live and the Connector connected to the wrong one, it can send a MIGRATE message to instruct the Connector to connect to the correct address.
- The old Worker remains alive until the the migration is complete.
    - This is slower, but it _feels_ safer.
    - The purpose of this is to avoid the case where the Connector is left stranded without a valid connection address

## Frame formats
```
MIGRATE
  - Frame tag: 8
  - String: host (U32 length + text bytes)
  - U16: port
MIGRATION_ACK:
  - Frame tag: 9
```

## Alternative approaches

1. Connection Map
    1. In this approach, the connector is started with a list of "seed addresses", similar to the way Cassandra works. These might be source addresses, or even control channel addresses.
    2. The connector attempts to connect to each of the seed addresses until one succeeds. 
    3. The worker on the other end provides the connector with the current map of connections (e.g. which sources are listening on what addresses)
    4. The connector then uses that map to determine what addresses to connect to.
    5. During a migration, the MIGRATION message includes an updated map.

2. "Not So Safe" approach
    1. The worker sends a Migrate message with a new address, then closes the connection
    2. The Connector connects to the worker at the new address, and goes through the regular handshake, using rollback to ensure no data was lost.
    3. This approach involves less coordination, but probably more resending of data
    4. It also runs the risk of the new address being wrong, leaving the Connector stranded

3. ???
    1. If you have any suggestions, please add them here!
