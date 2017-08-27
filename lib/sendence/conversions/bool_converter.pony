primitive BoolConverter
  fun bool_to_u8(x: Bool): U8 =>
    if x then 1 else 0 end

  fun u8_to_bool(x: U8): Bool =>
    if x > 0 then true else false end
