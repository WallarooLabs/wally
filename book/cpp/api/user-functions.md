# User Functions

There are two functions that the application developer must provide
themselves.

## `wallaroo::Serializable* w_user_data_deserialize (char* bytes_);`

This function receives a byte array and is responsible for decoding
the bytes and creating a new objects of the appropriate type with the
appropriate value. The application developer is responsible for
knowing how many bytes the message contains (either because it
contains a fixed number of bytes or because the length is encoded
somewhere in the byte array) and determining the correct type of
object to generate.

Objects of the following classes must be supported in the
`w_user_data_deserialize(...)` function:

* data passed as messages between steps (`wallaroo::Data`)
* state computations (`wallaroo::StateComputation`)
* sink encoders (`wallaroo::SinkEncoder`)
* keys (`wallaroo::Key`)
* state change builders (`wallaroo::StateChangeBuilder`)

## `extern bool w_main(int argc, char **argv, Application *application_builder_)`

This function is responsible for setting up the application using the
`application_builder_` object that is passed to it. In addition to the
`application_builder_` object, the function also receives the arguments
that were passed to the program when it was started, so that it can
use them to manage any runtime configuration that is required to build
the application.

If the application is sucessfully configured then function should
return `true`, otherwise it should return `false`.
