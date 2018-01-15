# Application

The application object is used to build the application. An
application object is passed to the `w_main(...)` function, which will
then call methods on the object to create the application and lay out
the pipelines within it.

All application object method return the application object itself, so
that the method calls can be chained.

```c++
class Application
{
private:
  void *m_application_builder;
  const char *m_name;
public:
  Application(void *application_builder_);
  ~Application();
  Application *create_application(const char *name_);
  Application *new_pipeline(
    const char* pipeline_name_,
    SourceDecoder *source_decoder_);
  Application *to(ComputationBuilder *computation_builder_);
  Application *to_stateful(
    StateComputation *state_computation_,
    StateBuilder *state_builder_,
    const char* state_name_);
  Application *to_state_partition(
    StateComputation *state_computation_,
    StateBuilder *state_builder_,
    const char* state_name_,
    Partition *partition_,
    bool multi_worker_);
  Application *to_state_partition_u64(
    StateComputation *state_computation_,
    StateBuilder *state_builder_,
    const char* state_name_,
    PartitionU64 *partition_,
    bool multi_worker_);
  Application *to_sink(SinkEncoder *sink_encoder_);
  Application *done();
};
```

## Methods

### `Application *create_application(const char *name_)`

Create a new Wallaroo application named `name_`. This method should
only be called once.

### `Application *new_pipeline(const char* pipeline_name_, SourceDecoder *source_decoder_)`

Within the current application, create a new pipeline `pipeline_name_`
that uses `source_decoder_` to decode incoming messages. This new
pipeline is considered the "current pipeline" until it is terminated
by a call to `to_sink(...)` or `done()`.

### `Application *to(ComputationBuilder *computation_builder_)`

Add a computation to the current pipeline. The `computation_builder_`
is responsible for building the computation that will be added.

### `Application *to_stateful(StateComputation *state_computation_, StateBuilder *state_builder_, const char* state_name_)`

Add a state computation to the current pipeline. The
`state_builder_` builds the state that will be used by the state
computation. state_name_ is the name of the collection of state objects 
that we will run state computations against. You can share state partitions across pipelines by using the same name. Using different names for different 
partitions, keeps them separate and in this way, acts as a sort of namespace.

### `Application *to_state_partition(StateComputation *state_computation_, StateBuilder *state_builder_, const char* state_name_, Partition *partition_, bool multi_worker_)`

Add a partitioned state computation to the current pipeline.

###  `Application *to_state_partition_u64(StateComputation *state_computation_, StateBuilder *state_builder_, const char* state_name_, PartitionU64 *partition_, bool multi_worker_)`

Add a partitioned state computation that uses a 64-bit integer partitioning key to the current pipeline.

### `Application *to_sink(SinkEncoder *sink_encoder_)`

Add a sink encoder to the current pipeline. This finishes the pipeline.

### `Application *done()`

Finish the current pipeline without a sink.
