# Data

This class represents message data that is passed from a source to a
computation or between computations.

```c++
{
class Data: public ManagedObject
{
public:
  virtual ~Data();
};
```

## Methods

### `virtual ~Data()`

This method deletes any objects that were allocated and owned by the data object.
