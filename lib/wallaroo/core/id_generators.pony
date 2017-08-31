use "sendence/guid"

class MsgIdGenerator
  let _guid: GuidGenerator = GuidGenerator

  fun ref apply(): MsgId =>
    _guid.u128()

class StepIdGenerator
  let _guid: GuidGenerator = GuidGenerator

  fun ref apply(): StepId =>
    _guid.u128()

class RouteIdGenerator
  let _guid: GuidGenerator = GuidGenerator

  fun ref apply(): RouteId =>
    _guid.u64()
