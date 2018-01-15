# C++ Sample Application

In order to understand how a Wallaroo application is created, it is useful to look at a sample application. The source code for the sample application can be found [`examples/cpp/alphabet-cpp`](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/cpp/alphabet-cpp).

## About The Application

This example application lets people vote on their favorite letter of the alphabet (a-z). It receives messages that consist of a single byte representing a character and four bytes that represent the number of new votes that should be added for this character. Each time it receives one of these messages, it outputs a message that consists of a single byte that represents the character followed by four bytes that represent the total number of votes that letter has received. Both the incoming and outgoing messages are framed by a four byte lengths that represent the number of bytes in the message (not including the bytes in the framing). The framing length and vote counts are a 32-bit big-endian integers.

## Defining a Stateful Application

### Defining the Application In C++

The application developer is responsible for creating a function called `w_main` that Wallaroo will call to set up the application. Here's our example `w_main` function:

```c++
extern bool w_main(int argc, char **argv, Application *application_builder_)
{
  application_builder_->create_application("Alphabet Popularity Contest")
    ->new_pipeline("Alphabet Votes", new VotesDecoder())
    ->to_state_partition_u64(
      new AddVotes(), // state_computation
      new LetterStateBuilder(), // state_builder
      "letter-state",
      new LetterPartition(),
      true // multi_worker
      )
    ->to_sink(new LetterTotalEncoder());

  return true;
}
```

This creates a new application called "Alphabet Popularity Contest", adds a new pipeline called "Alphabet Votes" with a `VotesDecoder`, adds a partitioned state computation to the pipeline, and then finishes the pipeline with a `LetterTotalEncoder` sink.

### Message Data

First, let's take a look at the message data that is used in our application.

Message data objects represent the data that flows through an application. Message data objects can pass between workers so they must implement the [`Serializable`](serialization.md) interface.

The `Votes` class represents an incoming message, which contains a letter and some votes to add to the vote total. It looks like this:

```c++
class Votes: public Data
{
public:
  char m_letter;
  uint32_t m_count;
  Votes(char l_, uint32_t c_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

Votes::Votes(char l_, uint32_t c_): m_letter(l_), m_count(c_)
{
}

void Votes::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::Votes;
  bytes_[1] = m_letter;
  *(uint32_t *)(bytes_ + 2) = htobe32(m_count);
}

size_t Votes::serialize_get_size ()
{
  return 6;
}
```

It stores the letter and the number of votes that the letter received. These messages are created at the source decoder when the application receives a message.

Here's the `LetterTotal` class:

```c++
class LetterTotal: public Data
{
public:
  char m_letter;
  uint32_t m_count;
  LetterTotal(char l_, uint32_t c_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

LetterTotal::LetterTotal(char l_, uint32_t c_): m_letter(l_), m_count(c_)
{
}

void LetterTotal::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::LetterTotal;
  bytes_[1] = m_letter;
  *(uint32_t *)(bytes_ + 2) = htobe32(m_count);
}

size_t LetterTotal::serialize_get_size ()
{
  return 6;
}
```

It stores the letter and the total number of votes that letter has received. These messages are encoded as a byte array when they reach the sink encoder.

### Application State

Wallaroo applications can store state. Here's our applications state class:

```c++
class LetterState: public State
{
public:
  LetterState();
  char m_letter;
  uint32_t m_count;
};

LetterState::LetterState(): m_letter(' '), m_count(0)
{
}
```

In this case, the state stores a letter and the number of votes it has received. When a state computation is run, its associated state is passed to the state computation. Our application partitions state, so there is one state object for each partition (remember that the partitions are for the letter a to z). So in this case each state object only has to keep track of the information for one letter, not all of the letters.

The application developer does not allocate state objects directly. Instead, the application developer provides a state builder that Wallaroo calls when it is ready to create a state object. In addition to creating a state object, the state builder also stores a name for the state. Wallaroo uses the name to determine if more than one state computation wants to use the same state object; if two builders return the same name then only one state object is generated and it is used by both state computations.

Here's our state builder:

```c++
class LetterStateBuilder: public StateBuilder
{
public:
  const char *name();
  State *build();
};

const char *LetterStateBuilder::name()
{
  return "LetterStateBuilder";
}

State *LetterStateBuilder::build()
{
  return new LetterState();
}
```

### The Source Decoder

The source decoder receives a byte array and turns it into a message data object that will be sent into the pipeline. Here's the class definition and method definitions for our source decoder:

```c++
class VotesDecoder: public SourceDecoder
{
public:
  virtual size_t header_length();
  virtual size_t payload_length(char *bytes_);
  virtual Data *decode(char *bytes_);
};

size_t VotesDecoder::header_length()
{
  return 4;
}

size_t VotesDecoder::payload_length(char *bytes_)
{
  return be32toh(*((uint32_t *)(bytes_)));
}

Data *VotesDecoder::decode(char *bytes_, size_t sz_)
{
  char letter = bytes_[0];
  uint32_t count = be32toh(*((uint32_t *)(bytes_ + 1)));
  return new Votes(letter, count);
}
```

Wallaroo calls the `header_length` method to determine how many bytes are in the message header, then sends that many bytes to `payload_length` in order to get the number of bytes in the message itself. Wallaroo then sends that many bytes to the `decode` method, where a new `Votes` message data object is created.

### The State Computation

Our application takes a `Votes` message, updates a state object that stores the total number of votes that a letter has received, and then sends out a `LetterTotal` message with the total number of votes the letter has received. The state computation is responsible for taking the incoming message data and state and producing the outgoing message, as well as passing along a state change object if the state object needs to be updated.

Here's what our state computation looks like:

```c++
class AddVotes: public StateComputation
{
  virtual const char *name();
  virtual void *compute(
    Data *input_,
    StateChangeRepository *state_change_repository_,
    void* state_change_repository_helper_, State *state_, void *none);
  virtual size_t get_number_of_state_change_builders();
  virtual StateChangeBuilder *get_state_change_builder(size_t idx_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

const char *AddVotes::name()
{
  return "add votes";
}

void *AddVotes::compute(
  Data *input_,
  StateChangeRepository *state_change_repository_,
  void* state_change_repository_helper_, State *state_, void *none)
{
  Votes *votes = static_cast<Votes *>(input_);

  LetterState *letter_state = static_cast<LetterState *>(state_);

  void *state_change_handle = w_state_change_repository_lookup_by_name(
    state_change_repository_helper_, state_change_repository_, AddVotesStateChange::s_name);

  AddVotesStateChange *add_votes_state_change =
    static_cast<AddVotesStateChange*>(
      w_state_change_get_state_change_object(
        state_change_repository_helper_, state_change_handle));

  add_votes_state_change->update(*votes);

  LetterTotal *letter_total =
    new LetterTotal(letter_state->m_letter, letter_state->m_count);

  return w_stateful_computation_get_return(
    state_change_repository_helper_, letter_total, state_change_handle);
}

size_t AddVotes::get_number_of_state_change_builders()
{
  return 1;
}

StateChangeBuilder *AddVotes::get_state_change_builder(size_t idx_)
{
  return new AddVotesStateChangeBuilder();
}

void AddVotes::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::AddVotes;
}

size_t AddVotes::serialize_get_size ()
{
  return 1;
}
```

The `name` method returns the name of the state computation.

The `compute` method does the actual work. It gets the state change handle (this is required by Wallaroo) by calling `w_state_change_repository_lookup_by_name` (if no state change handle can be found then it returns a pointer to `None`, which can be tested by comparing it to the `none` pointer that is passed into the method). It then uses this to get the state change object by calling `w_state_change_get_state_change_object`. It updates the state change object using the `Votes` message data and creates a new outgoing `LetterTotal` message object. Note that the `LetterTotal` object adds the count from the `Votes` data to the count in the state data, because the state object does not get updated until after the `compute` message is run. Finally, the `compute` uses the `w_stateful_computation_get_return` function to generate the return value using the outgoing `LetterTotal` message data and the state change handle.

State functions have zero or more state change builders associated with them. Each state change builder can build a state change, which represents a way of updating the state object. Wallaroo uses the `get_number_of_state_change_builders` method to determine how many state change builders are associated with the state computation, and then calls the `get_state_change_builder` method to get each state change builder. In our case there is only one state change builder.

State computations are passed to the worker that processes a given state partition, so they must implement the [Serializable](serialization.md) interface.

### State Changes

State objects are used by state computations, but they are not directly updated within the state computation. Instead, state computations return state change objects which Wallaroo later applies to the state. The state change object also provides methods that are used to write state changes to the recovery log and read them from the log during recovery.

If a new state change object was created each time a state computation was run then there could be a negative performance impact on the system. In order to avoid that, state change objects created once and then reused. They are accessed through the state change repository, which can be used to look up a state change handle and the associated state change.

Our application only has one state change. It increases the vote count for a letter. Here's our application's state change:

```c++
class AddVotesStateChange: public StateChange
{
private:
  uint64_t m_id;
  Votes m_votes;
public:
  static const char *s_name;

  AddVotesStateChange(uint64_t id_);
  virtual const char *name();
  virtual void apply(State *state_);
  virtual void to_log_entry(char *bytes_);
  virtual size_t get_log_entry_size();
  virtual size_t get_log_entry_size_header_size();
  virtual size_t read_log_entry_size_header(char *bytes_);
  virtual bool read_log_entry(char *bytes_);
  virtual uint64_t id();

  void update(Votes votes);
};

const char *AddVotesStateChange::s_name = "add votes state change";

AddVotesStateChange::AddVotesStateChange(uint64_t id): m_id(id), m_votes(' ', 0)
{
}

const char *AddVotesStateChange::name()
{
  return s_name;
}

void AddVotesStateChange::apply(State *state_)
{
  LetterState *letter_state = static_cast<LetterState *>(state_);

  letter_state->m_letter = m_votes.m_letter;
  letter_state->m_count += m_votes.m_count;
}

void AddVotesStateChange::to_log_entry(char *bytes_)
{
  bytes_[0] = m_votes.m_letter;
  *(uint32_t *)(bytes_ + 1) = htobe32(m_votes.m_count);
}

size_t AddVotesStateChange::get_log_entry_size()
{
  return 5;
}

size_t AddVotesStateChange::get_log_entry_size_header_size()
{
  return 0;
}

size_t AddVotesStateChange::read_log_entry_size_header(char *bytes_)
{
  return 0;
}

bool AddVotesStateChange::read_log_entry(char *bytes_)
{
  m_votes.m_letter = bytes_[0];
  m_votes.m_count = be32toh(*((uint32_t *)(bytes_ + 1)));
  return true;
}

void AddVotesStateChange::update(Votes votes_)
{
  m_votes = votes_;
}

uint64_t AddVotesStateChange::id()
{
  return m_id;
}
```

Our state change object has an `update` method that is used to set the data that will be used to update the state. After the state computation completes, Wallaroo calls the `apply` method to apply the stored
change to the state.

State change objects are not created directly by the developer, instead a state change builder object creates the state change object at some point. Our application's state change builder looks like this:

```c++
class AddVotesStateChangeBuilder: public StateChangeBuilder
{
public:
  virtual StateChange *build(uint64_t id_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

StateChange *AddVotesStateChangeBuilder::build(uint64_t id_)
{
  return new AddVotesStateChange(id_);
}

void AddVotesStateChangeBuilder::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::AddVotesStateChangeBuilder;
}

size_t AddVotesStateChangeBuilder::serialize_get_size ()
{
  return 1;
}
```

### Partitioning

Messages can be partitioned between Wallaroo workers based on a partition function. This allows a Wallaroo system to scale by adding workers. The application developer is responsible for defining a partition function that takes in message data and returns a partition key. The application developer is also responsible for specifying the known partition keys.

Each partition creates a separate state object that only stores state for the given partition.

Wallaroo takes care of deciding which partitions will live on which workers and routes messages to the appropriate workers.

Our partition looks like this:

```c++
class LetterPartition: public PartitionU64
{
  virtual PartitionFunctionU64 *get_partition_function();
  virtual size_t get_number_of_keys();
  virtual uint64_t get_key(size_t idx_);
};

PartitionFunctionU64 *LetterPartition::get_partition_function()
{
  return new LetterPartitionFunction();
}

size_t LetterPartition::get_number_of_keys()
{
  return 26;
}

uint64_t LetterPartition::get_key(size_t idx_)
{
  return 'a' + idx_;
}
```

The partition is responsible for returning a new partition function via the `get_partition_function` method, and returning partition keys via the `get_key` method. Wallaroo uses the `get_number_of_keys` method to determine how many keys it should get from the partition.

In our case, there are 26 partition keys, one for each letter of the alphabet. The `get_key` method returns a 64-bit value that is the ASCII value of the given letter.

#### The Partition Function

Our partition function looks like this:

```c++
uint64_t LetterPartitionFunction::partition(wallaroo::Data *data_)
{
  Votes *votes = static_cast<Votes *>(data_);
  return votes->m_letter;
}
```

It takes incoming message data (in our case, a `Votes` object) and returns a 64-bit integer that represents the partition to use for processing the message. In our case, the partition is the ASCII value of the letter that is receiving these votes.

### The Sink Encoder

When data leaves Wallaroo, it goes through a sink encoder. The sink encoder is responsible for taking a message data object and writing a representation of that object to a byte array. In our case, that means taking a `LetterTotal` object and writing out a message. Here's our sink encoder:

```c++
size_t LetterTotalEncoder::get_size(Data *data_)
{
  return 5;
}

void LetterTotalEncoder::encode(Data *data_, char *bytes_)
{
  LetterTotal *letter_total = static_cast<LetterTotal *>(data_);
  bytes_[0] = letter_total->m_letter;
  *(uint32_t *)(bytes_ + 1) = htobe32(letter_total->m_count);
}
```

Wallaroo calls the `get_size` method to figure out how large of a buffer to allocate for the outgoing message. The `encode` method then writes a representation of the data to the buffer. Notice that the encoder is responsible for any framing, so our `get_size` method returns `9` (`4` bytes for the framing length, `1` byte for the letter, and `4` bytes for the vote total).

### Serialization

Wallaroo moves some types of objects between workers (see the [Serialization](serialization.md) chapter) and it must be able to serialize and deserialize them. When Wallaroo needs to serialize an object it calls the serialization methods on it. But when Wallaroo receives serialized data and needs to deserialize it, it doesn't know the type of object it is dealing with, so it must call a general function that knows how to do deserialization. This function is defined by the application developer and is called `w_user_data_deserialize`. It takes a byte array and returns a object of the appropriate type with its value set using the contents of the incoming buffer. It is up to the application developer to decide how to encode and decode objects.

Our applications `w_user_data_deserialize` function looks like this:

```c++
namespace SerializationTypes
{
  // data
  const uint8_t Votes = 1;
  const uint8_t LetterTotal = 2;

  // state computations
  const uint8_t AddVotes = 3;

  // state change builders
  const uint8_t AddVotesStateChangeBuilder = 4;
};

extern wallaroo::Serializable* w_user_data_deserialize (char* bytes_)
{
  uint8_t serialization_type = bytes_[0];
  switch (serialization_type)
  {
  case SerializationTypes::Votes:
  {
    char letter = bytes_[1];
    char count = be32toh(*((uint32_t *)(bytes_ + 2)));
    return new Votes(letter, count);
  }
  case SerializationTypes::LetterTotal:
  {
    char letter = bytes_[1];
    char count = be32toh(*((uint32_t *)(bytes_ + 2)));
    return new LetterTotal(letter, count);
  }
  case SerializationTypes::AddVotes:
    return new AddVotes();
  case SerializationTypes::AddVotesStateChangeBuilder:
    return new AddVotesStateChangeBuilder();
  }

  return NULL;
}
```

The first byte in the serialized representation is a byte that indicates the type of the object, represented in our code as one of four `SerializationTypes` values. If it is a `Votes` or `LetterTotal` object then the second byte is the letter of the message, and the last four bytes represent the vote count. Otherwise, there is nothing else to read either a `AddVotes` or `AddVotesStateChangeBuilder` object is created.

In our case we can determine the size of the buffer by looking at the byte that represents the object type. If need to have variable length serialization representations then the developer must come up with a way of encoding that information in the data representation.
