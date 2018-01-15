# StateChange

A state change represents a change that will be made to a state
object. It is responsible for applying that change to the state object
that is passed to it, as well as serializing itself to the resilience
log and deserializing itself from a resilience log entry.

Log entries can be fixed or varible in length. If the message is
variable length then the length should be encoded in the first bytes
of the message. This class has methods for handling parts of this
work.

```c++
class StateChange: public ManagedObject
{
public:
  virtual const char *name() = 0;
  virtual void apply(State *state_) = 0;
  virtual void to_log_entry(char *bytes_) = 0;
  virtual size_t get_log_entry_size() = 0;
  virtual size_t get_log_entry_size_header_size() = 0;
  virtual size_t read_log_entry_size_header(char *bytes_) = 0;
  virtual bool read_log_entry(char *bytes_) = 0;
  virtual uint64_t id() = 0;
};
```

## Methods

### `virtual const char *name()`

This method returns the name of the state change object. This name is
used to look up the state change object inside state computations.

### `virtual void apply(State *state_)`

This method applies the state change to a state object.

### `virtual void to_log_entry(char *bytes_)`

This method writes the state change entry to the resilience log. If
the log entry is variable length and the length is stored as part of
the entry then this method is responsible for writing the bytes that
represent the length.

### `virtual size_t get_log_entry_size()`

This method returns the number of bytes that will be required to write
a log entry for the state change. If the log entry is vairable length
and the length is stored as part of the entry then this method must
include those bytes when calculating the entry size.

This method is also called when reading a log entry if the call to
`get_log_entry_size_header_size()` returned `0`.

### `virtual size_t get_log_entry_size_header_size()`

This method is used to tell wallaroo how many bytes were used in the
length header of the resilience log entry for this state change. The
returned value will be used to determine how many bytes are passed to
the `read_log_Entry_size_header(...)` method.

If there is no length header then `0` should be returned; in this
case, `get_log_entry_size()` will be called to determine the number of
bytes to pass to the `read_log_entry_(...)` method.

### `virtual size_t read_log_entry_size_header(char *bytes_)`

If the header length is greater than `0` then this method will be
called with an array of the size returned by
`get_log_entry_size_header_size()`. The method will return a number
representing the remaining bytes in the message.

### `virtual bool read_log_entry(char *bytes_)`

This method reads the bytes that represent the log entry and set the
internal state of the state change object using that data.

### `virtual uint64_t id()`

This method returns the id of the state change. This should be set by
the constructor when the state change is created by the associated
state change builder.
