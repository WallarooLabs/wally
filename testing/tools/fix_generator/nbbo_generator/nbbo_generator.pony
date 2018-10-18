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
    var messages_duration_secs: U64 = 0
    var nonrejected_instruments_file_path = ""
    var options = Options(env.args)
    var ini_file_path = ""

    options
      .add("properties_file", "f", StringArgument)

    for option in options do
      match option
      | ("properties_file", let arg: String) => ini_file_path = arg
      end
    end

    try
      var auth = env.root as AmbientAuth
      let ini_file = File(FilePath(env.root as AmbientAuth, ini_file_path)?)
      let sections = IniParse(ini_file.lines())?
      let nbbo_section = sections("nbbo")?
      nonrejected_instruments_file_path =
        nbbo_section("nonrejected_instruments_file")?
      output_folder = nbbo_section("output_folder")?
      output_msgs_per_sec = nbbo_section("output_msgs_per_sec")?.u64()?
      messages_duration_secs = nbbo_section("messages_duration_secs")?.u64()?

      let instruments_file = File(FilePath(auth,
        nonrejected_instruments_file_path)?)
      let instruments = generate_instruments(instruments_file)

      let nbbo_files_generator = NbboFilesGenerator(env, auth,
        output_msgs_per_sec, messages_duration_secs,
        output_folder, instruments)

      @printf[I32]("Starting nbbo generation...\n".cstring())
      nbbo_files_generator.write_to_files()
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

actor NbboFilesGenerator
  let _env: Env
  let _auth: AmbientAuth
  let _output_msgs_per_sec: U64
  let _messages_duration_secs: U64
  embed _wb: Writer = Writer
  let _number_generator: RandomNumberGenerator = RandomNumberGenerator()
  let _dice: Dice = Dice(_number_generator.random())
  let _file_extension: String = ".msg"
  let _time: (I64 val, I64 val) = Time.now()
  let _output_folder: String
  var _instruments: Array[InstrumentData val] val
  var _file_counter: U64 = 1
  var _file_limit_counter: I64 = 0
  var _file_limit: USize = 350000
  var _current_sec: U64 = 0
  var _output_path: String = ""

  new create(env: Env,
    auth: AmbientAuth,
    output_msgs_per_sec: U64,
    messages_duration_secs: U64,
    output_folder: String,
    instruments: Array[InstrumentData val] val)
  =>
    _env = env
    _auth = auth
    _output_msgs_per_sec = output_msgs_per_sec
    _messages_duration_secs = messages_duration_secs
    _output_folder = output_folder
    _instruments = instruments
    _wb.reserve_chunks(_file_limit)
    _output_path = recover val
      _output_folder.clone()
        .>append(_file_counter.string())
        .>append(_file_extension)
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

  be write_to_files() =>
    if _current_sec < _messages_duration_secs then
      generate_for_sec(_current_sec)
    else
      try
        var output_file = File(FilePath(_auth, _output_path)?)
        output_file.writev(_wb.done())
        output_file.dispose()
      end
      @printf[I32]("Finished writing generated NBBO messages to files\n"
        .cstring())
    end

  be generate_for_sec(sec: U64) =>
    try
      var output_file = File(FilePath(_auth, _output_path)?)
      let date = PosixDate(_time._1 + sec.i64(), _time._2)
      let utc_timestamp = date.format("%Y%m%d-%H:%M:%S.000")
      for x in Range[U64](0, _output_msgs_per_sec) do
        output_file = check_output_file_size(output_file)?
        generate_nbbo(utc_timestamp)?
      end
      _current_sec = _current_sec + 1
      write_to_files()
    end

  fun ref generate_nbbo(timestamp: String) ? =>
    let index = _dice(1, _instruments.size().u64()).usize() - 1
    let instrument = _instruments(index)?
    let fix_nbbo_msg = RandomFixNbboGenerator(instrument,
      _number_generator, false, timestamp)
    let fix_nbbo_string = FixMessageStringify.nbbo(fix_nbbo_msg)
    _file_limit_counter = _file_limit_counter + 1
    _wb.write(fix_nbbo_string)
