# StateBuilder

A state builder is responsible for creating state objects.

Two states with the same name are considered the same, while two
states with different names, even if they return the same type of
state object, are considered different. This allows to different
state computations to use the same state object if they have the
same name, while also allowing two different state objects of the same
type to be used in different places if they have different names.

```c++
class StateBuilder
{
public:
  virtual const char *name() = 0;
  virtual State *build() = 0;
};
```

## Methods

### `virtual const char *name()`

This method returns the name of this state instance.

### `virtual State *build()`

This method returns a state object.
