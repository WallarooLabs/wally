
// type PartialCompare is (PartialLess | PartialEqual | PartialGreater |
//   PartialIncomparable)

// primitive PartialLess is Equatable[PartialCompare]
//   fun string(): String iso^ =>
//     "Less".string()

// primitive PartialEqual is Equatable[PartialCompare]
//   fun string(): String iso^ =>
//     "Equal".string()

// primitive PartialGreater is Equatable[PartialCompare]
//   fun string(): String iso^ =>
//     "Greater".string()

// primitive PartialIncomparable is Equatable[PartialCompare]
//   fun string(): String iso^ =>
//     "Incomparable".string()

interface PartialComparable[A: PartialComparable[A] #read] is Equatable[A]
  fun lt(that: box->A): Bool
  fun gt(that: box->A): Bool
  fun le(that: box->A): Bool => lt(that) or eq(that)
  fun ge(that: box->A): Bool => gt(that) or eq(that)

  // fun compare(that: box->A): PartialCompare =>
  //   if eq(that) then
  //     PartialEqual
  //   elseif lt(that) then
  //     PartialLess
  //   elseif gt(that) then
  //     PartialGreater
  //   else
  //     PartialIncomparable
  //   end
