/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "wallaroo"
use "wallaroo/core/aggregations"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[Transaction](
          "Alerts (worker local aggregations)",
          GenSourceConfig[Transaction](
            TransactionsGeneratorBuilder(where amount_limit = 100)))

        transactions
          .local_key_by(ExtractUser)
          .to[TransactionGroup](LocalCheckTransactionTotal)
          .key_by(ExtractUser)
          .to[RunningTotal](CheckTransactionTotal)
          .to_sink(TCPSinkConfig[RunningTotal].from_options(
            RunningTotalEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Alerts", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

interface val Userable
  fun user(): String

primitive ExtractUser
  fun apply(t: Userable): String =>
    t.user()

class val Transaction
  let _user: String
  let amount: USize
  new val create(u: String, a: USize) =>
    _user = u
    amount = a
  fun user(): String => _user
  fun string(): String =>
    "Transaction(" + _user + ":" + amount.string() + ")\n"

class val TransactionGroup
  let _user: String
  let amount: USize
  new val create(u: String, a: USize) =>
    _user = u
    amount = a
  fun user(): String => _user

class val RunningTotal
  let user: String
  let amount: USize
  new val create(u: String, a: USize) =>
    user = u
    amount = a
  fun string(): String =>
    "RunningTotal(" + user + ":" + amount.string() + ")\n"

class TransactionTotal is State
  var total: USize = 0

primitive _Identity[A: Any val] is StatelessComputation[A, A]
  fun apply(a: A): A => a
  fun name(): String => "_Identity"

primitive LocalCheckTransactionTotal is
  StateComputation[Transaction, TransactionGroup, TransactionTotal]
  fun apply(transaction: Transaction, total: TransactionTotal):
    TransactionGroup
  =>
    total.total = total.total + transaction.amount
    TransactionGroup(transaction.user(), transaction.amount)

  fun initial_state(): TransactionTotal =>
    TransactionTotal

  fun name(): String => "Local Check Transaction"

primitive CheckTransactionTotal is
  StateComputation[TransactionGroup, RunningTotal, TransactionTotal]
  fun apply(transaction: TransactionGroup, total: TransactionTotal):
    RunningTotal
  =>
    total.total = total.total + transaction.amount
    RunningTotal(transaction.user(), total.total)

  fun initial_state(): TransactionTotal =>
    TransactionTotal

  fun name(): String => "Check Transaction"

primitive RunningTotalEncoder
  fun apply(rt: RunningTotal, wb: Writer): Array[ByteSeq] val =>
    wb.write(rt.string())
    wb.done()

primitive TotalAggregation is
  Aggregation[Transaction, TransactionGroup, TransactionTotal]

  fun initial_accumulator(): TransactionTotal =>
    TransactionTotal

  fun update(transaction: Transaction, t_total: TransactionTotal) =>
    t_total.total = t_total.total + transaction.amount

  fun combine(t1: TransactionTotal box, t2: TransactionTotal box):
    TransactionTotal
  =>
    let new_t = TransactionTotal
    new_t.total = t1.total + t2.total
    new_t

  fun output(user: String, window_end_ts: U64, t: TransactionTotal):
    TransactionGroup
  =>
    TransactionGroup(user, t.total)

  fun name(): String => "Total Aggregation"

/////////////////////////////////////////////////////////////////
// A GENERATOR FOR CREATING SIMULATED INPUTS TO THE APPLICATION
/////////////////////////////////////////////////////////////////
class val TransactionsGeneratorBuilder
  let _count: USize
  let _amount_limit: USize

  new val create(count: USize = 4, amount_limit: USize = 100) =>
    _count = count
    _amount_limit = amount_limit

  fun apply(): TransactionsGenerator
  =>
    TransactionsGenerator(_count, _amount_limit)

class TransactionsGenerator
  var cur_id: USize = 0
  var cur_amount: USize = 1
  var id_count: USize
  var limit: USize
  var still_sending: Bool = true

  new create(count: USize, amount_limit: USize) =>
    id_count = count
    limit = amount_limit
    if (id_count == 0) or (amount_limit == 0) then
      still_sending = false
    end

  fun ref initial_value(): (Transaction | None) =>
    _next_transaction()

  fun ref apply(t: Transaction): (Transaction | None) =>
    _next_transaction()

  fun ref _next_transaction(): (Transaction | None) =>
    if still_sending then
      let t = Transaction("Key-" + cur_id.string(), cur_amount)
      _advance_id()
      t
    end

  fun ref _advance_id() =>
    cur_id = (cur_id + 1) % id_count
    if cur_id == 0 then
      cur_amount = cur_amount + 1
      if cur_amount > limit then
        still_sending = false
      end
    end
