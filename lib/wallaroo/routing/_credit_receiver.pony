use "wallaroo/fail"
use "wallaroo/invariant"

interface _CreditReceiver
  fun ref receive_credits(credits: ISize)

class _EmptyCreditReceiver
  fun ref receive_credits(credits: ISize) =>
    Fail()

class _PreparingToWorkCreditReceiver
  let _route: _RouteLogic

  new create(r: _RouteLogic) =>
    _route = r

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

class _WorkingCreditReceiver
  let _route: _RouteLogic
  let _route_type: String
  let _step_type: String

  new create(r: _RouteLogic, r_type: String, step_type: String) =>
    _route = r
    _route_type = r_type
    _step_type = step_type

  fun ref receive_credits(credits: ISize) =>
    ifdef debug then
      Invariant(credits > 0)
      Invariant(_route.credits_available() <= _route.max_credits())
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
      @printf[I32]("--%sRoute (%s): rcvd %llu credits. Had %llu out of %llu.\n".cstring(),
        _route_type.cstring(), _step_type.cstring(), credits,
        _route.credits_available() - credits_recouped, _route.max_credits())
    end

    if _route.credits_available() > 0 then
      if (_route.credits_available() - credits_recouped) == 0 then
        _route._credits_replenished()
      end

      _route._update_request_more_credits_after(_route.credits_available() -
        (_route.credits_available() >> 2))
    else
      _route._request_credits()
    end

