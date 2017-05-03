# StateChangeBuilder

The state change builder is responsible to for building a state change
object. This allows the application developer to specify that a state
change should be built at a later point by Wallaroo.

A state change builder should always return new state change object of
the same type.

```c++
class StateChangeBuilder: public ManagedObject
{
public:
  virtual StateChange *build(uint64_t idx_) = 0;
};
```

## Methods

### `virtual StateChange *build(uint64_t idx_)`

This method returns a state change with it's id set to `idx_`.
