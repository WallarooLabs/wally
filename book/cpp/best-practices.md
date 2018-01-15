# C++ Best Practices

## Distinguish Between Encoding/Decoding and Serialization/Deserialization

On the surface, the problems of encoding/decoding message data and serializing/deserializing it may look similar. In the cases of encoding and serializing, the message is written to a buffer, and in the case of decoding and deserializing the message is read from a buffer. But it is important to remember that these tasks have fundamental differences.

Decoding is the process of taking data from the outside world and bringing it into Wallaroo, and encoding is the process of taking Wallaroo data and sending it to the outside world. On the other hand, serialization is the process of packaging data so that it can be moved from one Wallaroo worker to another, and deserialization is the process of unpacking that data on the receiving worker.

The systems with which your application communicates will most likely have their own data formats; these formats may contain fields that are not needed for your Wallaroo application. So while the source decoder may need to know about all of these fields, the serialization and deserialization methods only need be concerned with the information that is actually being used. By the same token, the sink decoder may need to write to a system that uses a format that is not the same as the one used by the serialization and deserialization code.

Another thing to keep in mind is that while encoding and decoding involve only message data, a Wallaroo application needs to be able to handle serialization and deserialization for more than just message data; it must also handle state computations, sink encoders, keys, and state change builders. Therefore, the serialization and deserialization formats must include information about the type of object that is being represented.

## Data Should Only Enter an Application From a Source

Wallaroo is designed around the idea of streaming data processing. Any state that is required by an application should be stored in a state object. And state objects should only be updated in response to incoming events. Accessing something like a database or a web service from inside a state computation will have a performance impact on the whole application. If you need data from another system, you should stream that data into Wallaroo and store it in a state object so that it can then be used by a state computation.

## Do Not Store Mutable Data In Global Variables

Wallaroo may run pieces of your application simultaneously in different threads. Using mutable global variables will introduce the possibility of data races, which will cause your application to behave unpredictably. If you try to use a mechanism like locking you run the risk of interfering with Wallaroo's own thread management, which may result in deadlocks.

## Do Not Create New Threads

Wallaroo manages its own threads in an efficient manner. Creating your own threads will negatively impact Wallaroo's performance. And as mentioned above, if you try to use mechanisms like locks to protect shared data then they may interfere with Wallaroo's thread management.

## Some Objects Should Not Store State

There are Wallaroo objects that are designed for storing state in member variables.

* message data objects
* state objects
* state change objects

Attempting to store state in other objects may not work as expected because Wallaroo may create new instances of objects or destroy existing ones as needed. For example, a new state computation object may be created each time it is needed, so if you increment a member variable that counts the number of times the `compute(...)` method has been called you may find that the value is always `1`.

## All Exceptions Should Be Caught

Exceptions should not be allowed to escape any methods. If an exception can be raised it should be caught and handled appropriately. You should design your application in such a way that if an error is possible then it is dealt with in a way that does not require all subsequent data processing to stop.
