primitive Bytes
  fun to_u16(high: U8, low: U8): U16 =>
    (high.u16() << 8) + low.u16()

  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) + (b.u32() << 16) + (c.u32() << 8) + d.u32()

  fun from_u16(u16: U16, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u16 and 0xFF).u8()
    let l2: U8 = ((u16 >> 8) and 0xFF).u8()
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun from_u32(u32: U32, arr: Array[U8] iso = recover Array[U8] end): Array[U8] iso^ =>
    let l1: U8 = (u32 and 0xFF).u8()
    let l2: U8 = ((u32 >> 8) and 0xFF).u8()
    let l3: U8 = ((u32 >> 16) and 0xFF).u8()
    let l4: U8 = ((u32 >> 24) and 0xFF).u8()
    arr.push(l4)
    arr.push(l3)
    arr.push(l2)
    arr.push(l1)
    consume arr

  fun length_encode(data: Array[U8] val): Array[U8] val =>
    let len: U32 = data.size().u32()
    let arr: Array[U8] iso = Bytes.from_u32(len, recover Array[U8] end)
    arr.append(data)
    consume arr
