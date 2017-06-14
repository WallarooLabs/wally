use "sendence/connemara"

actor TestMain is TestList
  new create(env: Env) => Connemara(env, this)

  new make() => None

  fun tag tests(test: Connemara) =>
    None
