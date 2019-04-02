/*

Copyright 2018 The Wallaroo Authors.

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

use "wallaroo_labs/options"
use "files"
use "buffered"
use "collections"
use "wallaroo_labs/fix"
use "wallaroo_labs/fix_generator_utils"
use "random"
use "ini"
use "time"

actor Main
  new create(env: Env) =>
    var output_folder: String = ""
    var output_msgs_per_sec: U64 = 0
    var msgs_processable_percent: U64 = 0
    var messages_duration_secs: U64 = 0
    var nonrejected_instruments_file_path = ""
    var rejected_instruments_file_path = ""
    var messages_skew_percent: U64 = 0
    var instruments_skew_percent: U64 = 0
    var rejection_percent_per_sec: F64 = 0.0
    var total_rejections: U64 = 0
    let options = Options(env.args)
    var ini_file_path = ""

    options
      .add("properties_file", "f", StringArgument)

    for option in options do
      match option
      | ("properties_file", let arg: String) => ini_file_path = arg
      end
    end

    try
      let auth = env.root as AmbientAuth
      let ini_file = File(FilePath(auth, ini_file_path)?)
      let sections = IniParse(ini_file.lines())?
      let orders_section = sections("orders")?
      output_folder = orders_section("output_folder")?
      rejected_instruments_file_path =
        orders_section("rejected_instruments_file")?
      nonrejected_instruments_file_path =
        orders_section("nonrejected_instruments_file")?
      output_msgs_per_sec = orders_section("output_msgs_per_sec")?.u64()?
      msgs_processable_percent =
        orders_section("msgs_processable_percent")?.u64()?
      messages_duration_secs = orders_section("messages_duration_secs")?.u64()?
      instruments_skew_percent =
        orders_section("instruments_skew_percent")?.u64()?
      messages_skew_percent =
        orders_section("messages_skew_percent")?.u64()?
      total_rejections =
        orders_section("total_rejections")?.u64()?
      rejection_percent_per_sec =
        (total_rejections.f64() /
          (messages_duration_secs * output_msgs_per_sec).f64())

      let rejected_instruments_file = File(FilePath(auth,
        rejected_instruments_file_path)?)
      let nonrejected_instruments_file = File(FilePath(auth,
        nonrejected_instruments_file_path)?)

      let instruments = generate_instruments(nonrejected_instruments_file)
      let rejected_instruments =
        generate_instruments(rejected_instruments_file)

      let order_file_generator = OrderFileGenerator(env, auth,
        output_msgs_per_sec, msgs_processable_percent,
        messages_duration_secs, messages_skew_percent,
        instruments_skew_percent, rejection_percent_per_sec,
        output_folder, instruments, rejected_instruments)

      @printf[I32]("Starting orders generation...\n".cstring())
      order_file_generator.write_to_files()
    end

  fun generate_instruments(instruments_file: File): Array[InstrumentData val] val =>
    let instruments = recover trn Array[InstrumentData val] end
    var is_header = true
    for line in instruments_file.lines() do
      if is_header then
        is_header = false
        continue
      end
      match InstrumentParser(consume line)
      | let instrument: InstrumentData val =>
        instruments.push(instrument)
      end
    end
    consume instruments

actor OrderFileGenerator
  let _env: Env
  let _auth: AmbientAuth
  let _output_msgs_per_sec: U64
  let _msgs_processable_percent: U64
  let _messages_duration_secs: U64
  let _messages_skew_percent: U64
  let _instruments_skew_percent: U64
  let _rejection_percent_per_sec: F64
  embed _wb: Writer = Writer
  let _number_generator: RandomNumberGenerator = RandomNumberGenerator()
  let _dice: Dice = Dice(_number_generator.random())
  let _file_extension: String = ".msg"
  let _time: (I64 val, I64 val) = Time.now()
  let _output_folder: String
  var _instruments: Array[InstrumentData val] val
  var _rejected_instruments: Array[InstrumentData val] val
  var _file_counter: U64 = 1
  var _file_limit_counter: I64 = 0
  var _file_limit: USize = 350000
  var _current_sec: U64 = 0
  var _output_path: String =  ""


  new create(env: Env,
    auth: AmbientAuth,
    output_msgs_per_sec: U64,
    msgs_processable_percent: U64,
    messages_duration_secs: U64,
    messages_skew_percent: U64,
    instruments_skew_percent: U64,
    rejection_percent_per_sec: F64,
    output_folder: String,
    instruments: Array[InstrumentData val] val,
    rejected_instruments: Array[InstrumentData val] val)
  =>
    _env = env
    _auth = auth
    _output_msgs_per_sec = output_msgs_per_sec
    _msgs_processable_percent = msgs_processable_percent
    _messages_duration_secs = messages_duration_secs
    _messages_skew_percent = messages_skew_percent
    _instruments_skew_percent = instruments_skew_percent
    _rejected_instruments = rejected_instruments
    _rejection_percent_per_sec = rejection_percent_per_sec
    _output_folder = output_folder
    _instruments = instruments
    _rejected_instruments = rejected_instruments
    _wb.reserve_chunks(_file_limit)
    _output_path = recover val
      _output_folder.clone()
        .>append(_file_counter.string())
        .>append(_file_extension)
    end

  be write_to_files() =>
    if _current_sec < _messages_duration_secs then
      generate_for_sec(_current_sec)
    else
      try
        var output_file = File(FilePath(_auth, _output_path)?)
        output_file.writev(_wb.done())
        output_file.dispose()
      end
    @printf[I32]("Finished writing generated orders to files\n".cstring())
    end

  fun ref check_output_file_size(output_file: File): File ?  =>
    match _file_limit_counter
    | _file_limit.i64() =>
      _file_limit_counter = 0
      output_file.writev(_wb.done())
      output_file.dispose()
      _file_counter = _file_counter + 1
      _output_path = recover val
        _output_folder.clone()
          .>append(_file_counter.string())
          .>append(_file_extension)
      end
      var new_output_file = File(FilePath(_auth, _output_path)?)
      new_output_file.set_length(0)
      new_output_file
    else
      output_file
    end

  fun ref should_reject_order(): Bool =>
    _number_generator() < _rejection_percent_per_sec

  fun ref should_be_heartbeat(): Bool =>
    _dice(1,100) > _msgs_processable_percent

  fun ref generate_heartbeat(timestamp: String) =>
    let heartbeat_string = FixMessageStringify.heartbeat(timestamp)
    _file_limit_counter = _file_limit_counter + 1
    _wb.write(heartbeat_string)

  fun ref generate_rejected_order(timestamp: String) ? =>
    let instrument_index =
      _number_generator.rand_int(_rejected_instruments.size().u64()).usize()
    let instrument =
      _rejected_instruments(instrument_index)?
    let fix_order_msg = RandomFixOrderGenerator(instrument, _dice,
      _number_generator, timestamp)
    let fix_order_string = FixMessageStringify.order(fix_order_msg)
    _file_limit_counter = _file_limit_counter + 1
    _wb.write(fix_order_string)

  fun ref generate_standard_order(timestamp: String) ? =>
    let instrument_index = generate_skewed_index()
    let instrument = _instruments(instrument_index.usize())?
    let fix_order_msg = RandomFixOrderGenerator(instrument,
      _dice, _number_generator, timestamp)
    let fix_order_string = FixMessageStringify.order(fix_order_msg)
    _file_limit_counter = _file_limit_counter + 1
    _wb.write(fix_order_string)


  fun ref generate_skewed_index(): U64 =>
    let instruments_size = _instruments.size().u64()
    if _dice(1,100) < _messages_skew_percent then
      let max_index =
        ((instruments_size * _instruments_skew_percent) / 100)
      _number_generator.rand_int(max_index)
    else
      _number_generator.rand_int(instruments_size)
    end

  be generate_for_sec(sec: U64) =>

  let rejected_instruments_size = _rejected_instruments.size().u64()
  let instruments_size = _instruments.size().u64()
  try
    var output_file = File(FilePath(_auth, _output_path)?)
    let date = PosixDate(_time._1 + sec.i64(), _time._2)
    var utc_timestamp = "0"
    try
      utc_timestamp = date.format("%Y%m%d-%H:%M:%S.000")?
    end
    for x in Range[U64](0, _output_msgs_per_sec) do
      output_file = check_output_file_size(output_file)?
      if should_reject_order() then
        generate_rejected_order(utc_timestamp)?
      else
        if should_be_heartbeat() then
          generate_heartbeat(utc_timestamp)
        else
          generate_standard_order(utc_timestamp)?
        end
      end
    end
    _current_sec = _current_sec + 1
    write_to_files()
  end
