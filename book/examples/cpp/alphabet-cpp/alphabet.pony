use "wallaroo/cpp_api/pony"

use "lib:wallaroo"
use "lib:c++"

use "lib:alphabet"

actor Main
  new create(env: Env) =>
    WallarooMain(env)
