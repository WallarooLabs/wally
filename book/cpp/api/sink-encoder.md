# SinkEncoder

The sink encoder takes data and sends it to other systems.

```c++
class SinkEncoder: public ManagedObject {
public:
  virtual size_t get_size(Data *data_) = 0;
  virtual void encode(Data *data_, char *bytes_) = 0;
};
```

## Methods

### 'virtual size_t get_size(Data *data_)'

This method returns the number of bytes required to encode the message
data.

### 'virtual void encode(Data *data_, char *bytes_)'

This method takes message data and a byte array and writes a
representation of the message data to the byte array. The byte array
has the number of bytes returned by `SinkEncoder::get_size(...)` when
it is called on the `data_` object.
