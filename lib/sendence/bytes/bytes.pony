use "buffered"
use "net"

primitive Bytes
  fun length_encode(data: ByteSeq val): Array[ByteSeq] val =>
    let len: U32 = data.size().u32()
    let wb = Writer
    if len > 0 then
      wb.u32_be(len)
      wb.write(data)
    end
    wb.done()

  fun to_u16(high: U8, low: U8): U16 =>
    (high.u16() << 8) or low.u16()

  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()

  fun to_u64(a: U8, b: U8, c: U8, d: U8, e: U8, f: U8, g: U8, h: U8): U64 =>
    (a.u64() << 56) or (b.u64() << 48) or (c.u64() << 40) or (d.u64() << 32)
    or (e.u64() << 24) or (f.u64() << 16) or (g.u64() << 8) or h.u64()

  fun from_u16(u16: U16, arr: Array[U8] iso = recover Array[U8](2) end): Array[U8] iso^ =>
    let l1: U8 = (u16 and 0xFF).u8()
    let l2: U8 = ((u16 >> 8) and 0xFF).u8()
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u32(u32: U32, arr: Array[U8] iso = recover Array[U8](4) end): Array[U8] iso^ =>
    let l1: U8 = (u32 and 0xFF).u8()
    let l2: U8 = ((u32 >> 8) and 0xFF).u8()
    let l3: U8 = ((u32 >> 16) and 0xFF).u8()
    let l4: U8 = ((u32 >> 24) and 0xFF).u8()
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u64(u64: U64, arr: Array[U8] iso = recover Array[U8](8) end): Array[U8] iso^ =>
    let l1: U8 = (u64 and 0xFF).u8()
    let l2: U8 = ((u64 >> 8) and 0xFF).u8()
    let l3: U8 = ((u64 >> 16) and 0xFF).u8()
    let l4: U8 = ((u64 >> 24) and 0xFF).u8()
    let l5: U8 = ((u64 >> 32) and 0xFF).u8()
    let l6: U8 = ((u64 >> 40) and 0xFF).u8()
    let l7: U8 = ((u64 >> 48) and 0xFF).u8()
    let l8: U8 = ((u64 >> 56) and 0xFF).u8()
    arr.push(l8)
    arr.push(l7)
    arr.push(l6)
    arr.push(l5)
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_f32(f32: F32, arr: Array[U8] iso = recover Array[U8](4) end):
    Array[U8] iso^
  =>
    from_u32(f32.bits(), consume arr)

  fun from_f64(f64: F64, arr: Array[U8] iso = recover Array[U8](8) end):
    Array[U8] iso^
  =>
    from_u64(f64.bits(), consume arr)

  fun u16_from_idx(idx: USize, arr: Array[U8]): U16 ? =>
    Bytes.to_u16(arr(idx), arr(idx + 1))

  fun u32_from_idx(idx: USize, arr: Array[U8]): U32 ? =>
    Bytes.to_u32(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3))

  fun u64_from_idx(idx: USize, arr: Array[U8]): U64 ? =>
    Bytes.to_u64(arr(idx), arr(idx + 1), arr(idx + 2), arr(idx + 3),
      arr(idx + 4), arr(idx + 5), arr(idx + 6), arr(idx + 7))
