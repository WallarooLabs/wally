# StateComputation

```c++
class StateComputation: public ManagedObject
{
public:
  virtual const char *name() = 0;
  virtual void *compute(Data *input_,
    StateChangeRepository *state_change_repository_,
    void* state_change_respository_helper_, State *state_, void *none) = 0;
  virtual size_t get_number_of_state_change_builders() = 0;
  virtual StateChangeBuilder *get_state_change_builder(size_t idx_) = 0;
};
```

### Methods

#### `virtual const char *name()`

This method returns the name of the state computation. This name is
used for logging and reporting.

#### `virtual void *compute(Data *input_, StateChangeRepository *state_change_repository_, void* state_change_respository_helper_, State *state_, void *none)`

This method performs a state computation using a the `input_` message data
and state from the state object. The `state_change_repository_` and
`state_change_repository_helper_` are used to look up state change
objects.

The method returns an object that is made up of the message data to
pass along to the next step and a state change object handle that
represents the change to apply to the state. For more information, see
the example application in [`examples/cpp/alphabet-cpp`](https://github.com/WallarooLabs/wallaroo-examples/tree/{{ book.wallaroo_version }}/examples/cpp/alphabet-cpp).

#### `virtual size_t get_number_of_state_change_builders()`

This method returns the number of state change builders associated
with this state computation.

#### `virtual StateChangeBuilder *get_state_change_builder(size_t idx_)`

This method returns a state change builder object associated with the
index `idx_`.

*Note:* The state change builder object should be allocated in this
method and returned. It should not be stored in a pre-allocated array
and returned.
