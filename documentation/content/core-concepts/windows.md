---
title: "Windows"
menu:
  docs:
    parent: "core-concepts"
    weight: 6
toc: true
---
Wallaroo supports windowing over aggregations. This allows you to break an infinite stream into manageable chunks and also allows you to see how your inputs evolve over time.

There are two broad categories of windows currently supported: count-based and range-based. Range-based windows can be further divided into tumbling and sliding varieties. We'll look at each of these in turn.

If you are not familiar with aggregations in Wallaroo, it might be helpful to read [this section](/core-concepts/aggregations) before proceeding.

## Count-based Windows

Count-based windows emit an output every `n` input messages, where `n` is specified via the API. For example (using the Python API):

```python
    (inputs
        .to(wallaroo.count_windows(5)
            .over(MySumAgg))
        .to_sink(sink_config))
```

This performs the user-defined `MySumAgg` aggregation for every 5 inputs. 

```
Messages:
01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 
|-------------|--------------|--------------|--------------|
    window 1      window 2       window 3       window 4
    sum = 15      sum = 40       sum = 65       sum = 90
```

## Range-based Windows

Range-based windows are defined based on specific time-based ranges. They fall into two categories, tumbling and sliding. We'll look at tumbling first.

### Tumbling Windows

Tumbling range-based windows are non-overlapping fixed-size time-based windows.
For example, let's define windows with a range of 3 seconds:

```python
    (inputs
        .to(wallaroo.range_windows(wallaroo.seconds(3))
            .over(MySumAgg))
        .to_sink(...))
```

Assuming we start from time 00:00, this would produce the following tumbling windows:

```
 Time (min:sec):
|00:00|00:01|00:02|00:03|00:04|00:05|00:06|00:07|00:08|00:09|00:10|00:11
|-----------------|-----------------|-----------------|-----------------|
     window 1          window 2          window 3          window 4
   [00:00,00:03)     [00:03,00:06)     [00:06,00:09)     [00:09,00:12)
```

Each window above is indicated by an interval such as `[00:00,00:03)`, indicating "the window containing all times equal to or greater than `00:00` and less than `00:03`".

Incoming messages will be placed in a window based on the event time of the message. In the near future, you will be able to derive this event time from each input message that arrives at a Wallaroo source. For now, it is always the ingest time for the input message.

So if we had the following four messages (min:sec.ms):
```
<id: 1, event_time: 00:04.043>
<id: 2, event_time: 00:01.022>
<id: 3, event_time: 00:06.000>
<id: 4, event_time: 00:09.055>
```

They would be placed as follows:
```
<id: 1, event_time: 00:04.043> --> window 2 [00:03,00:06)
<id: 2, event_time: 00:01.022> --> window 1 [00:00,00:03)
<id: 3, event_time: 00:06.000> --> window 3 [00:06,00:09)
<id: 4, event_time: 00:05.655> --> window 2 [00:03,00:06)
```

Notice that it doesn't matter which order the messages arrive in. They will be placed in the correct windows based on event time.

However, if there were no limit to how late messages can be, then we would have to keep around the state for each window indefinitely. This can add up quickly in a high-volume scenario. As a result, we currently throw away window data once the window output is triggered (i.e. the aggregation `output()` method is called and an output is produced for the window). This means that from then on, late messages are dropped on the floor. In future versions of Wallaroo, we will provide more fine-grained policies so that you can choose other options for late messages. In the meantime, the one knob we provide is a `delay` on triggering a window. For example:

```python
    (inputs
        .to(wallaroo.range_windows(wallaroo.seconds(3))
            .with_delay(wallaroo.seconds(3))
            .over(MySumAgg))
        .to_sink(sink_config))
```

This says that we delay triggering each window for 3 seconds. Think of the delay knob as setting either (1) an estimation of the maximum lateness for messages or (2) the lateness threshold beyond which you no longer care about messages. The knob is essentially trading off between latency (longer delays means longer waits for window outputs) and completeness (shorter delays potentially mean more ignored messages). 

IMPORTANT NOTE: If your application requires a guarantee that no messages are ever ignored, then it's not currently safe to use the Wallaroo windowing API unless you are certain that no messages will ever be later than your delay setting. However, as mentioned above, we will be adding more fine-grained policy control for late message in future versions.

### Window Triggers

We have talked about triggering window outputs but have not yet explained how this happens. There are two types of events that can potentially trigger a window output (corresponding to a call to the `output()` method on the underlying aggregation): (1) a message arrives at the window stage, and (2) a timeout is triggered. Each of these potentially triggers window outputs in different ways, so we'll look at them each in turn.

#### Message Trigger

When a message arrives at the window stage, we attempt to determine whether or not we have seen all messages for a given window, at which point we can trigger its output. We make this determination based on an event time watermark system internal to Wallaroo. As messages come into our system, we use their event timestamps to update these watermarks. We then propagate the latest watermarks downstream. A watermark is an estimate of how far we have progressed in event time up to a particular stage. It serves as a heuristic for determining whether we have seen all messages destined for a certain window. When using this heuristic in practice, we also take into account the user-defined `delay` parameter explained above. 

If a window ends at time 00:10, and the user-defined delay is 00:02, then we will trigger that window's output once we have a watermark passing the 00:12 mark. We check our watermark against our windows every time we receive a message at a stage containing those windows.

#### Timeout Trigger

If we only triggered window outputs based on incoming messages, then we would be left with a potential straggler problem. Imagine that our window range is defined in seconds but our incoming stream stopped sending for hours at a time. The last group of messages might have been placed in windows, but we never received a message with a watermark high enough to trigger those windows. In this situation, the latency for those windows would end up being hours long, since we'd have to wait for the stream to start up again to get a chance to trigger them.

This is where timeouts come in. We use timeouts to periodically check if we have not heard from our upstreams past a certain threshold. Currently, neither the timeouts nor the threshold are directly configurable by the user (though this will change in future releases). We set both the timeout and the threshold as a function of the window range plus the user-defined delay. If the threshold is passed, then we trigger the window outputs.

### Sliding Windows

Sliding range-based windows are overlapping fixed-size time-based windows.
For example, let's define windows with a range of 6 seconds and a slide of 3 seconds:

```python
    (inputs
        .to(wallaroo.range_windows(wallaroo.seconds(6))
            .with_slide(wallaroo.seconds(3))
            .over(MySumAgg))
        .to_sink(...))
```

Assuming we start from time 00:00, this would produce the following sliding windows:

```
 Time (min:sec):
|00:00|00:01|00:02|00:03|00:04|00:05|00:06|00:07|00:08|00:09|00:10|00:11
|-----------------------------------|
   [00:00,00:06)                     
                  |-----------------------------------|
                     [00:03,00:09)                       
                                    |-----------------------------------|
                                        [00:06,00:12)     
                                                      |------------------
                                                          [00:09,00:15)     
```

Notice how these windows overlap. Messages will be assigned to more than one window at a time. Using our examples from above:
```
<id: 1, event_time: 00:04:043>
<id: 2, event_time: 00:01:022>
<id: 3, event_time: 00:06:000>
<id: 4, event_time: 00:09:055>
```

These would be placed in our sliding windows as follows:
```
<id: 1, event_time: 00:04:043> --> [00:00,00:06) and [00:03,00:09)
<id: 2, event_time: 00:01:022> --> [00:00,00:06)
<id: 3, event_time: 00:06:000> --> [00:03,00:09) and [00:06,00:12)
<id: 4, event_time: 00:05:655> --> [00:00,00:06) and [00:03,00:09)
```

Tumbling windows are actually a special case of sliding windows where the window range and slide are equal. 
