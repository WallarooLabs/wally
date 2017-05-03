# C++ Memory Management

Objects that are returned to Wallaroo by application-developer-defined functions and methods are memory managed by Wallaroo. Objects should have destructors that ensure that all memory allocated by the object is deleted when the object itself is deleted unless otherwise specified (there are a few exceptions).
