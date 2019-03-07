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
