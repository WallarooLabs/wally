# Test

## Test

Let's start by looking at how to create a linear pipeline of computations.
We're going to start simple by creating an app that converts Celsius values to
Fahrenheit. You may recall that he conversion goes as follows:

```
f = (c * 1.8) + 32  
```

Even though this could easily define a single computation, we're going to break
it into two to illustrate chaining. So we start with the multiplication step:

```
primitive Multiply is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input * 1.8

  fun name(): String => "Multiply by 1.8"
```

A few points of interest. First, we are naming our computation `Multiply` and define it as a `primitive`. You can think of a `primitive` as a stateless class. Second, we specify that it is a `Computation` transforming values of type `F32` (32-bit floats) to values of type `F32`. Third, we define an `apply`
method that constitutes the computation logic itself. Finally, all 
`Computation` objects must implement a `name` method for performance
monitoring purposes.

We similarly define the addition step:

```
primitive Add is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input + 32

  fun name(): String => "Add 32"
```

Our application consists of a single pipeline which takes an `F32`, passes it
to a `Multiply`, which passes it to an `Add`, which passes it to a sink for 
sending to external systems. Here is all the code for defining the application
(we'll break it down step by step):

```
Application("Celsius Conversion App")
  .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
    .to[F32]({(): Multiply => Multiply})
    .to[F32]({(): Add => Add})
    .to_sink(FahrenheitEncoder, recover [0] end)
```

The first line is simple:

```
Application("Celsius Conversion App")
```

This begins our application definition by passing in a name. We then define
our pipeline:

```
  .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
```

This says that our series of computations begins with an `F32` and ends with
an `F32`. The pipeline is called "Celsius Conversion". And incoming data is
decoded via `CelsiusDecoder` to get us our initial Celsius values (which will 
be of type `F32`). We'll talk about decoding and encoding later.

Next we chain together our two computations:

```
    .to[F32]({(): Multiply => Multiply})
    .to[F32]({(): Add => Add})
```

The type argument tells us the _output_ type for the computation, in this case `F32` since we are only working with `F32` values in this application. The
system infers the input type for each computation. We pass in a lambda that 
takes no arguments (hence the empty parens) and outputs the relevant computation type.

Finally we define our sink for the pipeline:

```
    .to_sink(FahrenheitEncoder, recover [0] end)
```

The `FahrenheitEncoder` transforms the Fahrenheit values (which are of type
`F32`) to sequences of bytes for transmission via TCP. The `recover [0] end` clause says that we are using the sink with id 0. Currently Wallaroo only supports one sink per pipeline.





