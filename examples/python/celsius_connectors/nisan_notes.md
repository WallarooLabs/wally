# example user controller

class MyController(Wallaroo.AtLeastOnceController):

  def handle_reset(self, point_of_ref):

  def handle_next(self) # -> (data, point_of_ref)
    # blocking yield
    # controller select() is polling this

  def handle_close(self) # optional

  def handle_open(self) # optional

  def handle_progress(self, stream_id, point_of_ref)
    # for trimming history in the connector or upstream non-volatile buffers



my_controller = MyController() # Start asyncore.loop in background thread
my_controller.start()

# enter user's data read loop/server/what-have-you
# e.g.
my_server = MyTCPListener(host, port, my_controller)
my_server.server_forever()



## Kafka case
Consumer groups have a tricky difficulty at initialization
Issues with moving things to the right position
Issues with errors
Allowing Kafka to do Kafka specific things that are outside of the Wallaroo protocol scope
- e.g. what happens if your target offset is not available?


## Things to think about in terms of the controller class:
- initialization
- handling Ok
- handling multiple partitions/keys in multiple streams


Order is guaranteed per stream
It's possible to put a bound on disorder over multiple streams (e.g. globally ordered epochs, but locally fuzzy ordered)

If you wrote a kafka connector that can support multiple topics, partition_id is no longer unique
so you'll need to use something else (e.g. a somewhat collision-resistant hash function)

What happens if another connector is started and reads from the same kafka partitions
- The rule is that all independent connectors must come up with the same enumeration of stream-id and stream-name.
- That way, no one is using a stream-id differently anywhere else
- As long as the stream-id is deterministic



Connector1
  Part1 [1,2,3,4,5]
  Part2 [1,2,3,4,5]

Connector2
  part2 [1,2,3,4,5]
  part3 [1,2,3,4,5]

Wallaroo
  get: connector1.part2(1,2,3)
  get. connector2.part2(3,4,5) ??? What to do here?
    # determinism allows us to drop (3) as already processed
    # OR: Wallaroo should inform Connector2 that "hey, stream 'part2' is already used"
    # - This is done in notify_ack, in response to notify
    # Maybe it makes sense to fail the connector when running into this kind of collision
    # not sure which policy makes the most sense: random, newest, oldest, etc.
    # maybe only fail if out of any valid streams
    # Once we go multi-worker-sources it will change everything.


e.g. Start Kafka with two connectors, two consumers, each takes 6 partitions out of total 12
A third connector is added to increase capacity
Third connector takes 2 partitions from each of the existing connector
Existing connectors should be able to handle this hand off of partitions/streams
e.g. signal "end of stream/EOS" at the old session
     new connector starts with a new notify on that stream

e.g.
  new session notify's
  old session should 
