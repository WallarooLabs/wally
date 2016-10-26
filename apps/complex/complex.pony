"""
Setting up a complex app run (in order):
1) reports sink:
nc -l 127.0.0.1 7002 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 7003 >> /dev/null

3a) single worker complex app:
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n worker-name --ponythreads=1

3b) 2-worker complex app:
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 2 -t -n worker1 --ponythreads=1
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 2 -n worker2 --ponythreads=1

3c) 3-worker complex app:
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -t -n worker1 --ponythreads=1
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker2 --ponythreads=1
./complex -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -w 3 -n worker3 --ponythreads=1

4) complex numbers:
giles/sender/sender -b 127.0.0.1:7010 -m 10000000 -s 300 -i 2_500_000 -f apps/complex/complex_numbers.msg -r --ponythreads=1 -y -g 12
"""

use "buffered"
use "sendence/bytes"
use "wallaroo/topology"

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

class val Conjugate is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    // @printf[I32]("Conjugating...\n".cstring())
    input.conjugate()

  fun name(): String => "Get Conjugate"

class val Scale is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    // @printf[I32]("Scaling...\n".cstring())
    input * 5

  fun name(): String => "Scale by 5"

class ComplexSourceDecoder
  fun apply(data: Array[U8] val): Complex val ? =>
    let real = Bytes.to_u32(data(0), data(1), data(2), data(3))
    let imaginary = Bytes.to_u32(data(4), data(5), data(6), data(7))
    Complex(real.i32(), imaginary.i32())

primitive ComplexEncoder
  fun apply(c: Complex val, wb: Writer = Writer): Array[ByteSeq] val =>
    // Header
    wb.u32_be(8)
    // Fields
    wb.i32_be(c.real())
    wb.i32_be(c.imaginary())
    wb.done()

