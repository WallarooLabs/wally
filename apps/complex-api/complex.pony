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
use "wallaroo"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let topology = recover val
        Topology
          .new_pipeline[Complex val, Complex val](ComplexDecoder, 
            "Complex Numbers")
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^
            => Conjugate end)
          .to[Complex val](lambda(): Computation[Complex val, Complex val] iso^=> Scale(5) end)
          .to_sink(ComplexEncoder, recover [0] end)
      end
      Startup(env, topology)//, 1)
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

  fun string(fmt: FormatSettings[FormatDefault, PrefixDefault] 
    = FormatSettingsDefault): String iso^
  =>
    ("C(" + _real.string() + ", " + _imaginary.string() + ")").clone()

class iso Conjugate is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    input.conjugate()

  fun name(): String => "Get Conjugate"

class Scale is Computation[Complex val, Complex val]
  let _scalar: I32
  let _name: String

  new iso create(scalar: I32) =>
    _scalar = scalar
    _name = "Scale by " + _scalar.string()

  fun apply(input: Complex val): Complex val =>
    input * _scalar

  fun name(): String => _name

primitive ComplexDecoder
  fun apply(data: Array[U8] val): Complex val ? => 
    let real = Bytes.to_u32(data(0), data(1), data(2), data(3))
    let imaginary = Bytes.to_u32(data(4), data(5), data(6), data(7))
    Complex(real.i32(), imaginary.i32())

primitive ComplexEncoder
  fun apply(c: Complex val, wb: Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(8)
    // Fields
    wb.i32_be(c.real())
    wb.i32_be(c.imaginary())
    wb.done()

