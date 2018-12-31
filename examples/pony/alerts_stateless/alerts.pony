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
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/gen_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[Transaction]("Alerts (stateless)",
          GenSourceConfig[Transaction](TransactionsGeneratorBuilder))

        transactions
          .to[Alert](CheckTransaction)
          .to_sink(TCPSinkConfig[Alert].from_options(
            AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Alerts", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val Transaction
  let amount: F64
  new val create(a: F64) =>
    amount = a

interface val Alert
  fun amount(): F64
  fun string(): String

class val DepositAlert
  let _amount: F64
  new val create(a: F64) =>
    _amount = a

  fun amount(): F64 =>
    _amount

  fun string(): String =>
    "DepositAlert: " + _amount.string() + "\n"

class val WithdrawalAlert
  let _amount: F64
  new val create(a: F64) =>
    _amount = a

  fun amount(): F64 =>
    _amount

  fun string(): String =>
    "WithdrawalAlert: " + _amount.string() + "\n"

primitive CheckTransaction is StatelessComputation[Transaction, (Alert | None)]
  fun apply(transaction: Transaction): (Alert | None) =>
    if transaction.amount > 1000 then
      DepositAlert(transaction.amount)
    elseif transaction.amount < -1000 then
      WithdrawalAlert(transaction.amount)
    else
      None
    end

  fun name(): String => "Check Transaction"

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
  fun initial_value(): Transaction =>
    Transaction(1)

  fun apply(t: Transaction): Transaction =>
    // A simplistic way to get some numbers above, below, and within our
    // thresholds.
    let amount = ((((t.amount * 2305843009213693951) + 7) % 2500) - 1250)
    Transaction(amount)
