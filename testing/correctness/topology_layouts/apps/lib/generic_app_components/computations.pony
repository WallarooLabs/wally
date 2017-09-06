use "wallaroo/core/topology"

primitive Double is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    input * 2

  fun name(): String => "Double"

primitive Divide is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    input / 2

  fun name(): String => "Divide"

primitive OddFilter is Computation[U64, U64]
  fun apply(input: U64): (U64 | None) =>
    if ((input % 2) == 0) then
      input
    else
      None
    end

  fun name(): String => "OddFilter"
