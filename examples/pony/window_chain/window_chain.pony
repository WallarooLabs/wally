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
use "time"
use "wallaroo"
use "wallaroo/core/aggregations"
use "wallaroo/core/common"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "wallaroo/core/windows"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[UserAndAmount]("Alerts (windowed)",
            TCPSourceConfig[UserAndAmount]
              .from_options(NoopDecoder,
                            TCPSourceConfigCLIParser(env.args)?(0)?
                            where parallelism' = 512))
        transactions
          .to[UserAndAmount](Identity[UserAndAmount])
          .key_by(ExtractUser)
          .to[Alert](Wallaroo.range_windows(Seconds(1))
                      .over[UserAndAmount, UserAndAmount, TransactionTotal](
                        TotalAggregation))
          .to[Alert](Wallaroo.range_windows(Seconds(2))
                      .over[UserAndAmount, UserAndAmount, TransactionTotal](
                        TotalAggregation2))
          .to_sink(TCPSinkConfig[UserAndAmount].from_options(
            AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Alerts", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end


primitive Identity[A: Any val] is StatelessComputation[A, A]
  fun name() : String =>
    "Identity"

  fun apply(a: A) : A =>
    a

interface val UserAndAmount
  fun user(): String
  fun amount(): F64
  fun string(): String
  fun event_timestamp(): U64 => 0

class val Transaction is UserAndAmount
  let _user: String
  let _amount: F64
  let _event_ts: U64
  new val create(u: String, a: F64, ets: U64 = 0) =>
    _user = u
    _amount = a
    _event_ts = ets
  fun user(): String => _user
  fun amount(): F64 => _amount
  fun string(): String =>
    "Transaction(" + _user + "," + _amount.string() + ")"
  fun event_timestamp(): U64 => _event_ts

primitive ExtractUser
  fun apply(t: UserAndAmount): Key =>
    t.user()

class TransactionTotal is State
  var total: F64 = 0.0

interface val Alert is UserAndAmount
  fun user(): String
  fun amount(): F64
  fun string(): String

class val DepositAlert is UserAndAmount
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

class val WithdrawalAlert is UserAndAmount
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

primitive CheckTransaction is StateComputation[UserAndAmount, (Alert | None),
  TransactionTotal]
  fun apply(transaction: UserAndAmount, t_total: TransactionTotal):
    (Alert | None)
  =>
    t_total.total = t_total.total + transaction.amount()
    if t_total.total > 2000 then
      DepositAlert(transaction.user(), t_total.total)
    elseif t_total.total < -2000 then
      WithdrawalAlert(transaction.user(), t_total.total)
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

  fun update(transaction: UserAndAmount, t_total: TransactionTotal) =>
    @printf[I32]("udpate Aggregation1\n".cstring())
    t_total.total = t_total.total + transaction.amount()

  fun combine(t1: TransactionTotal box, t2: TransactionTotal box):
    TransactionTotal
  =>
    let new_t = TransactionTotal
    new_t.total = t1.total + t2.total
    new_t

  fun output(user: Key, window_end_ts: U64, t: TransactionTotal):
    (Alert | None)
  =>
    @printf[I32]("TRIGGERED!!!!!!! AGGREGATION1\n".cstring())
    WithdrawalAlert(user, t.total)

  fun name(): String => "Total Aggregation"

primitive TotalAggregation2 is
  Aggregation[Transaction, (Alert | None), TransactionTotal]
  fun initial_accumulator(): TransactionTotal =>
    TransactionTotal

  fun update(transaction: UserAndAmount, t_total: TransactionTotal) =>
    @printf[I32]("udpate Aggregation2\n".cstring())
    t_total.total = t_total.total + transaction.amount()

  fun combine(t1: TransactionTotal box, t2: TransactionTotal box):
    TransactionTotal
  =>
    let new_t = TransactionTotal
    new_t.total = t1.total + t2.total
    new_t

  fun output(user: Key, window_end_ts: U64, t: TransactionTotal):
    (Alert | None)
  =>
    @printf[I32]("TRIGGERED!!!!!!! AGGREGATION2\n".cstring())
    DepositAlert(user, t.total)

  fun name(): String => "Total Aggregation2"


primitive AlertsEncoder
  fun apply(alert: UserAndAmount, wb: Writer): Array[ByteSeq] val =>
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

  fun initial_value(): UserAndAmount =>
    Transaction("Fido", 1)

  fun ref apply(t: UserAndAmount): UserAndAmount =>
    // A simplistic way to get some numbers above, below, and within our
    // thresholds.
    var amount = ((((t.amount() * 2305843009213693951) + 7) % 2500) - 1250)
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

primitive NoopDecoder is FramedSourceHandler[UserAndAmount]
  fun header_length(): USize => 4

  fun payload_length(data: Array[U8] iso): USize ? =>
    USize.from[U32](data.read_u32(0)?.bswap())

  fun decode(data: Array[U8] val): UserAndAmount =>
    try
      let user = (Time.nanos() % 5).string()
      let amount = (Time.nanos() % 100).f64()
      let t = data.read_u32(0)?.bswap()
      Transaction(consume user, amount, t.u64() * 1_000_000_000)
    else
      @printf[I32]("failed to parse\n".cstring())
      Fail()
      Transaction("", 0, 0)
    end

  fun event_time_ns(t: UserAndAmount): U64 =>
    t.event_timestamp()
