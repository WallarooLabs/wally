use "sendence/fix"
use "collections"

actor Main
  var fx: FixOrderMessage val = recover
      FixOrderMessage(Buy, "", "", "", 1.0, 1.0, "")
    end

  new create(env: Env) =>
    let msg = "8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01"
      + "21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01"
      + "55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01"
      + "10=108\x01"

    for i in Range(0, 1_000_000) do
      match FixParser(msg)
      | let m: FixOrderMessage val => fx = m
      else
        None
      end
    end
