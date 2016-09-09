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

  fun string(fmt: FormatSettings[FormatDefault, PrefixDefault] 
    = FormatSettingsDefault): String iso^
  =>
    ("C(" + _real.string() + ", " + _imaginary.string() + ")").clone()

class val Conjugate is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    input.conjugate()

  fun name(): String => "Get Conjugate"

class val Scale is Computation[Complex val, Complex val]
  fun apply(input: Complex val): Complex val =>
    input * 5

  fun name(): String => "Scale by 5"

class ComplexSourceParser 
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

