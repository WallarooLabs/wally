# SourceDecoder

A source decoder is a source for messages. It is responsible for
taking an array of bytes and converting them into a message data
object. It assumes that messages are framed using some number of
bytes that represent the message length.

```c++
class SourceDecoder: public ManagedObject
{
public:
  virtual std::size_t header_length() = 0;
  virtual std::size_t payload_length(char *bytes_) = 0;
  virtual Data *decode(char *bytes_, size_t sz_) = 0;
};
```

## Methods

### `virtual std::size_t header_length()`

This method returns the number of bytes that should be read to get the
framing length of the message.

### `virtual std::size_t payload_length(char *bytes_)`

This method takes the framing bytes and converts them to the number of
bytes in the message.

### `virtual Data *decode(char *bytes_, size_t sz_)`

This method takes the message bytes and the size. The `bytes_` array
does not include the framing bytes from the incoming data, `sz_` tells
how many bytes the `bytes_` array contains.
