use "wallaroo/invariant"

class TypedRoutePreparingToWorkCreditReceiver[In: Any val]
  let _route: TypedRoute[In]

  new create(tr: TypedRoute[In]) =>
    _route = tr

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(_route.credits_available() == 0)
      Invariant(credits > 0)
    end

    _route._close_outstanding_request()

    let credits_recouped =
      if (_route.credits_available() + credits) > _route.max_credits() then
        _route.max_credits() - _route.credits_available()
      else
        credits
      end
    _route._recoup_credits(credits_recouped)

    if credits > credits_recouped then
      _route._return_credits(credits - credits_recouped)
    end
    ifdef "credit_trace" then
      @printf[I32]("--Route (Prep): rcvd %llu credits. Used %llu. Had %llu out of %llu.\n".cstring(),
        credits, credits_recouped,
        _route.credits_available() - credits_recouped, _route.max_credits())
    end

    _route._update_request_more_credits_after(_route.credits_available() -
      (_route.credits_available() >> 2))
    _route._credits_initialized()
    _route._report_ready_to_work()
