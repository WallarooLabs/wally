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
use "wallaroo/core/common"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"
use "wallaroo_labs/time"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[Transaction]("Alerts (windowed)",
          GenSourceConfig[Transaction](TransactionsGeneratorBuilder))

        transactions
          .key_by(ExtractUser)
          .to[Alert](Wallaroo.range_windows(Seconds(5))
                      .over[Transaction, Alert, TransactionTotal](
                        TotalAggregation))
          .to_sink(TCPSinkConfig[Alert].from_options(
            AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Alerts", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val Transaction
  let user: String
  let amount: F64
  new val create(u: String, a: F64) =>
    user = u
    amount = a

primitive ExtractUser
  fun apply(t: Transaction): Key =>
    t.user

class TransactionTotal is State
  var total: F64 = 0.0

interface val Alert
  fun user(): String
  fun amount(): F64
  fun string(): String

class val DepositAlert
  let _user: String
  let _amount: F64
  new val create(u: String, a: F64) =>
    _user = u
    _amount = a

  fun user(): String =>
    _user

  fun amount(): F64 =>
    _amount

  fun string(): String =>
    "DepositAlert for " + _user + ": " + _amount.string() + "\n"

class val WithdrawalAlert
  let _user: String
  let _amount: F64
  new val create(u: String, a: F64) =>
    _user = u
    _amount = a

  fun user(): String =>
    _user

  fun amount(): F64 =>
    _amount

  fun string(): String =>
    "WithdrawalAlert for " + _user + ": " + _amount.string() + "\n"

primitive CheckTransaction is StateComputation[Transaction, (Alert | None),
  TransactionTotal]

  fun apply(transaction: Transaction, t_total: TransactionTotal):
    (Alert | None)
  =>
    t_total.total = t_total.total + transaction.amount
    if t_total.total > 2000 then
      DepositAlert(transaction.user, t_total.total)
    elseif t_total.total < -2000 then
      WithdrawalAlert(transaction.user, t_total.total)
    else
      None
    end

  fun initial_state(): TransactionTotal =>
    TransactionTotal

  fun name(): String => "Check Transaction"


primitive TotalAggregation is
  Aggregation[Transaction, (Alert | None), TransactionTotal]

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

  fun output(user: Key, window_end_ts: U64, t: TransactionTotal):
    (Alert | None)
  =>
    if t.total > 2000 then
      DepositAlert(user, t.total)
    elseif t.total < -2000 then
      WithdrawalAlert(user, t.total)
    else
      None
    end

  fun name(): String => "Total Aggregation"

primitive AlertsEncoder
  fun apply(alert: Alert, wb: Writer): Array[ByteSeq] val =>
    wb.write(alert.string())
    wb.done()

/////////////////////////////////////////////////////////////////
// A GENERATOR FOR CREATING SIMULATED INPUTS TO THE APPLICATION
/////////////////////////////////////////////////////////////////
class val TransactionsGeneratorBuilder
  fun apply(): TransactionsGenerator =>
    TransactionsGenerator

class TransactionsGenerator
  var _user_idx: USize = 0
  let _user_totals: Array[F64] = [1.0; 0.0; 0.0; 0.0; 0.0]
  let _users: Array[String] = ["Fido"; "Rex"; "Dr. Whiskers"; "Feathers"
    "Mountaineer"]

  fun initial_value(): Transaction =>
    Transaction("Fido", 1)

  fun ref apply(t: Transaction): Transaction =>
    // A simplistic way to get some numbers above, below, and within our
    // thresholds.
    var amount = ((((t.amount * 2305843009213693951) + 7) % 2500) - 1250)
    _user_idx = (_user_idx + 1) % _users.size()
    let user = try _users(_user_idx)? else "" end
    let total = try _user_totals(_user_idx)? else -1 end
    if total > 5000 then
      amount = -6000
    elseif total < -5000 then
      amount = 6000
    end
    try _user_totals(_user_idx)? = total + amount end
    Transaction(user, amount)
