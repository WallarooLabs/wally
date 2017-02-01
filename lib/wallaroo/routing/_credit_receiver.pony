use "wallaroo/fail"
use "wallaroo/invariant"

trait _CreditReceiver
  fun ref receive_credits(route: _RouteLogic, credits: ISize)

class ref _NotYetReadyRoute is _CreditReceiver
  fun ref receive_credits(route: _RouteLogic, credits: ISize) =>
    ifdef debug then
      Invariant(route.credits_available() == 0)
      Invariant(credits > 0)
    end

    route._close_outstanding_request()

    let credits_recouped =
      if (route.credits_available() + credits) > route.max_credits() then
        route.max_credits() - route.credits_available()
      else
        credits
      end
    route._recoup_credits(credits_recouped)

    if credits > credits_recouped then
      route._return_credits(credits - credits_recouped)
    end
    ifdef "credit_trace" then
      @printf[I32](("--Route (Prep): rcvd %llu credits. Used %llu." +
        "Had %llu out of %llu.\n").cstring(),
        credits, credits_recouped,
        route.credits_available() - credits_recouped, route.max_credits())
    end

    route._update_request_more_credits_after(route.credits_available() -
      (route.credits_available() >> 2))
    route._credits_initialized()

class ref _ReadyRoute is _CreditReceiver
  fun ref receive_credits(route: _RouteLogic, credits: ISize) =>
    ifdef debug then
      Invariant(credits > 0)
      Invariant(route.credits_available() <= route.max_credits())
    end

    route._close_outstanding_request()
    let credits_recouped =
      if (route.credits_available() + credits) > route.max_credits() then
        route.max_credits() - route.credits_available()
      else
        credits
      end

    route._recoup_credits(credits_recouped)
    if credits > credits_recouped then
      route._return_credits(credits - credits_recouped)
    end

    ifdef "credit_trace" then
      @printf[I32](("-Route (Ready): rcvd %llu credits." +
        " Had %llu out of %llu.\n").cstring(),
        credits, route.credits_available() - credits_recouped,
        route.max_credits())
    end

    if route.credits_available() > 0 then
      if (route.credits_available() - credits_recouped) == 0 then
        route._credits_replenished()
      end

      route._update_request_more_credits_after(route.credits_available() -
        (route.credits_available() >> 2))
    else
      route._request_credits()
    end
