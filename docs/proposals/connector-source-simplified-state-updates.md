# Simplified stat eupdate sequences for the connector source protocol with sources on multiple workers and source migration

## States

### notifier
(class instance on connector source)

- _pending_notify
- _active_streams
- _pending_close
- _pending_relinquish


### local registry
(class instance on connector source listener)

- _active_streams (stream_id, (stream_name, connector source, last_acked, last_seen))


### global registry
(class instance on connector source listener)

- _active_streams (stream_id, worker_name)
- _inactive_streams (stream_id, last acked por)


## Sequences

```
-> = delegate
@ terminate/return to sender
```

### Simplified notify

```
notifier
  -> is in any local state?
    -> reject @
  -> ask listener, put stream_id in pending_notify

listener
  -> check local registry
    -> accept @ (see below
    -> reject @ (see below)
  -> check global registry @ (see below)

local registry
  -> is in _active_streams?
    -> owned by requester?
      -> accept @
    -> else reject @
  -> else go to global

global registry
  -> am I leader?
    -> is in _inactive?
      -> move from _inactive to _active, owned by requester
      -. accept @
    -> is in _active?
      -> reject @
    -> accept @ (new stream)
```

### Simplified stream_update

```
notifier
  -> barrier_complete
  -> update local state
  -> update listener
listener
  -> update local registry
```

### Simplified EOS

```
notifier
  -> move stream from _active to _pending_notify
  -> wait for barrier_complete
  -> barrier_complete
    -> update local state (last_seen = last_acked, checkpoint_id =...)
    -> _relinquish request
    -> move from _pending_notify to _pending_relinquish (stream_id, stream_state)
```

### Simplified relinquish

```
notifier
  -> _relinquish request
  -> listener.relinquish_request(stream_id, last_ack)
listener
  -> local_registry.relinquish_request
    -> global_registry.relinquish_request
      -> am I leader?
        -> is stream in _active? request name matches?
          -> move from _active to _inactive
          -> ack @
        -> nack @
      -> connections -> leader -> global registry
    -> local_registry ack relinquish
    -> notifier ack relinquish
notifier
  -> remove from _pending_relinquish
```



At the end of a recovery, local_registry relinquishes any streams that don't have a connector_source associated with them


## Listener checkpoint logic

_This part is preparation for when John's barrier protocol updates are ready_


State hierarchy:

Listener
  - local registry
    - global registry
    -< active sources
      - notifiers

Communication order:

notifier -> source -> listener -> local registry -> global registry or other active sources


Creating a checkpoint (return Array[ByteSeq]):

listener.create_checkpoint()
  -> local_registry.create_checkpoint()
    -> serialize local () +
       serialize global()
       // + length encoding or whatever's needed

       /* This part will be used in some fashion when john's work is done:
          /* we currently save this state in the notifier, so it's not necessary here */
       + sources.get_checkpoints()
       */

listener.rollback(payload; Array[U8], ...)
  ->
    deserialize and save local and global states
