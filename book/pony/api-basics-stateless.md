# API Basics: Stateless App

## Defining an Application

We'll begin digging into the Wallaroo API by creating a linear pipeline of
stateless computations. All the code in this section can be found in
[`examples/pony/celsius/celsius.pony`](https://github.com/WallarooLabs/wallaroo-examples/tree/0.1.1/examples/pony/celsius/celsius.pony).

We're going to start by creating an application that
converts Celsius values to Fahrenheit. You may recall that the conversion goes
as follows:

```pony
f = (c * 1.8) + 32
```

Even though this could define a single computation, we're going to break
it into two to illustrate chaining. So let's start with the multiplication step:

```pony
primitive Multiply is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input * 1.8

  fun name(): String => "Multiply by 1.8"
```

A few points of interest. First, we are naming our computation `Multiply` and
define it as a `primitive`. You can think of a `primitive` as a stateless class.
Second, we specify that `Multiply` is a `Computation` transforming values of type
`F32` (32-bit floats) to values of type `F32`. Third, we define an `apply` method
that constitutes the computation logic itself. Finally, all `Computation` objects
must implement a `name` method for performance monitoring purposes, so we include
one here.

We similarly define the addition step:

```pony
primitive Add is Computation[F32, F32]
  fun apply(input: F32): F32 =>
    input + 32

  fun name(): String => "Add 32"
```

Our application consists of a single pipeline which takes an `F32`, passes it
to a `Multiply`, which passes it to an `Add`, which passes it to a sink for
sending to external systems. Here is all the code for defining the application
itself (we'll break it down step by step):

```pony
Application("Celsius Conversion App")
  .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
    .to[F32]({(): Multiply => Multiply})
    .to[F32]({(): Add => Add})
    .to_sink(FahrenheitEncoder, recover [0] end)
```

The first line is simple:

```pony
Application("Celsius Conversion App")
```

This begins our application definition by passing in a name. We then define
our pipeline:

```pony
  .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
```

This says that our series of computations begins with an `F32` and ends with
an `F32`. The pipeline is called "Celsius Conversion". And incoming data is
decoded via `CelsiusDecoder` to get us our initial Celsius values (which will
be of type `F32`). We'll talk about decoding and encoding later.

Next we chain together our two computations:

```pony
    .to[F32]({(): Multiply => Multiply})
    .to[F32]({(): Add => Add})
```

The type argument tells us the _output_ type for the computation, in this case
`F32` since we are only working with `F32` values in this application. The
system infers the input type for each computation. We pass in a lambda that
takes no arguments (hence the empty parens) and outputs the relevant computation
type.

Finally we define our sink for the pipeline:

```pony
    .to_sink(FahrenheitEncoder, recover [0] end)
```

The `FahrenheitEncoder` transforms the Fahrenheit values (which are of type
`F32`) to sequences of bytes for transmission via TCP. The `recover [0] end`
clause says that we are using the sink with id 0. Currently Wallaroo only
supports one sink per pipeline.

## Hooking into Wallaroo

In order to actually use our app, we need to pass the `Application` object we
just defined to Wallaroo. We'll create a file called `conversion.pony` and
define a `Main` actor (which is the Pony equivalent of `main()` in C). Here's
our `Application` definition in context:

```pony
use "wallaroo"
use "wallaroo/core/source/tcp-source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Celsius Conversion App")
          .new_pipeline[F32, F32]("Celsius Conversion", CelsiusDecoder)
            .to[F32]({(): Multiply => Multiply})
            .to[F32]({(): Add => Add})
            .to_sink(FahrenheitEncoder, recover [0] end)
      end
      Startup(env, application, "celsius-conversion")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
```

All Wallaroo Pony applications must currently include the three packages included
at the top. Currently, we only support tcp sources, though this will
change in the near future.

You can treat most of this new code as boilerplate for now, except for this line:

```pony
      Startup(env, application, "celsius-conversion")
```

The `Startup` object is the entry point into Wallaroo itself. We pass the
Pony environment, our application, and a string to use for tagging files and
metrics related to this app.

## Decoding and Encoding

If you are using TCP to send data in and out of the system, then you need a way
to convert streams of bytes into semantically useful types and convert your
output types to streams of bytes. This is where the decoders and encoders
mentioned earlier come into play. For more information, see
[Decoders and Encoders](decoders-and-encoders.md).
