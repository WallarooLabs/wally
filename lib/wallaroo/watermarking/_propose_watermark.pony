interface Values[A]
  fun values(): Iterator[this->A]

primitive _ProposeWatermark
  fun apply(filter_route: _FilteredOnStep,
    routes: Values[_AckedOnRoute]): U64
  =>
    """
    Determine what we can propose as a new watermark for flushing.

    Basic algo is as follows:

      If each route is fully acked; IE every message sent has been acknowledged
      then we can use the highest value as our new watermark. Basically, if
      all work has been done then the last piece of work done is our
      watermark.

      If any route is not fully acked; IE at lease one message that we sent
      downstream hasn't yet been acknowledged then we use the lowest value from
      a not fully acknowledged route as our watermark.

      So...

      Route | Sent | Ack
        A       0     0
        B       2     1
        C       5     5
        D       7     4

      Both B and D have unacknowleged work. The two ack values are 1 and 4.
      From this, we can acknowledge that work up to 1 has been done. We know
      that 2 is outstanding as is 6 and 7.

      Another example:

      Route | Sent | Ack
        A       0     0
        B       3     1
        C       5     5
        D       7     4

      Both B and D have unacknowleged work. The two ack values are 1 and 4.
      From this, we can acknowledge that work up to 1 has been done. We know
      that 3 is outstanding as is 6 and 7. Its unclear, unlike our previous
      example whether 2 has been handled.

      Another example:

      Route | Sent | Ack
        A       0     0
        B       9     1
        C       5     5
        D       7     4

      Both B and D have unacknowleged work. The two ack values are 1 and 4.
      From this, we can acknowledge that work up to 1 has been done as we
      are unable to determine if 2 or 3 have been acknowledged. We know
      that 6,7,8 and 9 definitely haven't because they are above the highest
      acknowledged value.
    """
    let fully_acked = _all_routes_acked(routes)
    var watermark = if fully_acked then
      filter_route.highest_seq_id()
    else
      U64.max_value()
    end

    for route in routes.values() do
      if fully_acked then
        // If every route is fully acked then we want
        // the highest acked value
        if route.highest_seq_id_acked() > watermark then
          watermark = route.highest_seq_id_acked()
        end
      else
        // If not every route is fully acked then we want
        // the lowest acked value from a route that isn't
        // full acked
        if not route.is_fully_acked()
          and (route.highest_seq_id_acked() < watermark)
        then
          watermark = route.highest_seq_id_acked()
        end
      end
    end

    watermark

  fun _all_routes_acked(routes: Values[_AckedOnRoute]): Bool =>
    for route in routes.values() do
      if not route.is_fully_acked() then
        return false
      end
    end

    true
