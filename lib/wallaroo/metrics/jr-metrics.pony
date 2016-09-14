actor JrMetrics
  var start_t: U64 = 0
  var next_start_t: U64 = 0
  var end_t: U64 = 0
  var last_report: U64 = 0
  let _name: String
  new create(name: String) =>
    _name = name

  be set_start(s: U64) =>
    if start_t != 0 then
      next_start_t = s
    else
      start_t = s
    end
    @printf[I32]("Start: %zu\n".cstring(), start_t)

  be set_end(e: U64, expected: USize) =>
    end_t = e
    let overall = (end_t - start_t).f64() / 1_000_000_000
    let throughput = ((expected.f64() / overall) / 1_000).usize()
    @printf[I32]("%s End: %zu\n".cstring(), _name.cstring(), end_t)
    @printf[I32]("%s Overall: %f\n".cstring(), _name.cstring(), overall)
    @printf[I32]("%s Throughput: %zuk\n".cstring(), _name.cstring(), throughput)
    start_t = next_start_t
    next_start_t = 0
    end_t = 0

  be report(r: U64, s: U64, e: U64) =>
    last_report = (r + s + e) + last_report