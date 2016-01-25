use "assert"

primitive BuffyProtocol
  fun encode(msg: String): String =>
    let hexFormat = FormatSettingsInt.set_format(FormatHexBare)
    let hh = msg.size().string(hexFormat)
    let l = hh.size().string()
    l + (hh + msg)

  fun decode(packet: Array[U8] iso): Array[U8] iso^ ? =>
    """
    Decode LHHT*
    """
    try
      let hlen = _hex_to_4bits(packet(0))

      var h: USize = 0
      var count: USize = 1
      try
        while count <= hlen do
          let next = _hex_to_4bits(packet(count))
          h = (h << 4) or next
          count = count + 1
        end
      else
        error
      end

      Fact(packet.size() == (h + hlen + 1))
      packet.remove(0, hlen + 1)
      consume packet
    else
      error
    end

  fun _hex_to_4bits(x: U8): USize ? =>
    """
    Turn a hex value into 4 bits.
    """
    match x
    | if (x >= '0') and (x <= '9') => x.usize() - '0'
    | if (x >= 'A') and (x <= 'F') => (x.usize() - 'A') + 10
    | if (x >= 'a') and (x <= 'f') => (x.usize() - 'a') + 10
    else
      error
    end
