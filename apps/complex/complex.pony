"""
Setting up a complex app run (in order):
1) reports sink:
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 7003 >> /dev/null

3a) single worker complex app:
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n worker-name

3b) multi-worker complex app:
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -t -n worker1
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker2
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker3

4) complex numbers:
giles/sender/sender -b 127.0.0.1:7010 -m 10000000 -s 300 -i 2_500_000 -f apps/complex/complex_numbers.msg -r --ponythreads=1 -y -g 12
"""

use "buffered"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Complex Numbers App")
          .new_pipeline[Complex val, Complex val]("Complex Numbers", ComplexDecoder)
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^
            => Conjugate end)
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^
            => Scale(5) end)
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^
            => Scale(10) end)
          .to_stateful[Complex val, Counter](UpdateCounter,
            CounterBuilder, "counter-builder")
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^
            => Conjugate end)
          .to_sink(ComplexEncoder, recover [0] end)
      end
      Startup(env, application, None)//, 1)
    else
      env.out.print("Couldn't build topology")
    end

class Complex
  let _real: I32
  let _imaginary: I32

  new val create(r: I32, i: I32) =>
    _real = r
    _imaginary = i

  fun real(): I32 => _real
  fun imaginary(): I32 => _imaginary

  fun plus(c: Complex val): Complex val =>
    Complex(_real + c._real, _imaginary + c._imaginary)
 
  fun minus(c: Complex val): Complex val =>
    Complex(_real - c._real, _imaginary - c._imaginary)

  // fun times(c: Complex val): Complex val =>

  fun mul(u: I32): Complex val =>
    Complex(u * _real, u * _imaginary)

  fun conjugate(): Complex val =>
    Complex(_real, -_imaginary)

  fun string(): String iso^
  =>
    ("C(" + _real.string() + ", " + _imaginary.string() + ")").clone()

class iso Conjugate is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    @printf[I32]("Conjugate\n".cstring())
    input.conjugate()

  fun name(): String => "Get Conjugate"

class Scale is Computation[Complex val, Complex val]
  let _scalar: I32
  let _name: String

  new iso create(scalar: I32) =>
    _scalar = scalar
    _name = "Scale by " + _scalar.string()

  fun apply(input: Complex val): Complex val =>
    @printf[I32]((_name + "\n").cstring())
    input * _scalar

  fun name(): String => _name

primitive ComplexDecoder is FramedSourceHandler[Complex val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): Complex val ? => 
    let real = Bytes.to_u32(data(0), data(1), data(2), data(3))
    let imaginary = Bytes.to_u32(data(4), data(5), data(6), data(7))
    Complex(real.i32(), imaginary.i32())

primitive ComplexEncoder
  fun apply(c: Complex val, wb: Writer): Array[ByteSeq] val =>
    @printf[I32]("Got a result!\n".cstring())
    // Header
    wb.u32_be(8)
    // Fields
    wb.i32_be(c.real())
    wb.i32_be(c.imaginary())
    wb.done()

class Counter
  var _count: USize = 0 
  var _reals: I32 = 0

  fun ref apply(c: Complex val): Complex val =>
    _count = _count + 1
    _reals = _reals + c.real()
    @printf[I32](("Updated Counter to " + _count.string() + "\n").cstring())
    c

  fun count(): USize => _count
  fun reals(): I32 => _reals

primitive CounterBuilder
  fun name(): String => "Counter"
  fun apply(): Counter => Counter

primitive UpdateCounter
  fun name(): String => "UpdateCounter"
  fun apply(c: Complex val, sc_repo: StateChangeRepository[Counter], 
    state: Counter): (Complex val, None) 
  =>
    @printf[I32]("UpdateCounter\n".cstring())
    (state(c), None)

  fun state_change_builders(): Array[StateChangeBuilder[Counter] val] val =>
    recover Array[StateChangeBuilder[Counter] val] end

