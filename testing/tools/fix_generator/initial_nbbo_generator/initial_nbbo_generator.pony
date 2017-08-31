use "sendence/options"
use "files"
use "buffered"
use "collections"
use "debug"
use "sendence/fix"
use "sendence/fix_generator_utils"
use "random"
use "time"

actor Main
  let _env: Env

  new create(env: Env) =>
    _env = env
    let options = Options(env.args)
    var rejected_symbols_file_path = ""
    var symbols_file_path = ""
    var output_file_path = ""

    options
      .add("rejected_symbols_file", "r", StringArgument)
      .add("symbols_file", "s", StringArgument)
      .add("output", "o", StringArgument)
      .add("help", "h", None)

    for option in options do
      match option
      | ("rejected_symbols_file", let arg: String) =>
        rejected_symbols_file_path = arg
      | ("symbols_file", let arg: String) =>
        symbols_file_path = arg
      | ("output", let arg: String) => output_file_path = arg
      | ("help", None) =>
        help()
        return
      end
    end

    if (rejected_symbols_file_path == "") or (output_file_path == "") or
       (symbols_file_path == "") then
      help()
      return
    end

    try
      let auth = env.root as AmbientAuth

      let nonrejected_symbols_file =
        File(FilePath(auth, symbols_file_path))
      let rejected_symbols_file =
        File(FilePath(auth, rejected_symbols_file_path))
      let rejected_instruments =
        generate_instruments(rejected_symbols_file)
      let nonrejected_instruments =
        generate_instruments(nonrejected_symbols_file)

      let initial_nbbo_file_generator =
        InitialNbboFileGenerator(env, auth, output_file_path, rejected_instruments, nonrejected_instruments)

      initial_nbbo_file_generator.generate_and_write()
    end

  fun help() =>
    @printf[I32](
      """
      PARAMETERS:
      -----------------------------------------------------------------------------------
      --rejected_symbols_file/-r [Sets file to read rejected symbols from]
      --symbols_file/-s [Sets file to read non rejected symbols from]
      --output/-o [Sets file to write to]
      -----------------------------------------------------------------------------------
      """.cstring())

  fun generate_instruments(instruments_file: File):
    Array[InstrumentData val] val
  =>
    let instruments = recover trn Array[InstrumentData val] end
    var is_header = true
    let reader = Reader
    reader.append(instruments_file.read(instruments_file.size()))
    while true do
      let line = try
        reader.line()
      else
        break
      end

      if is_header then
        is_header = false
        continue
      end
      match InstrumentParser(line)
      | let instrument: InstrumentData val =>
        instruments.push(instrument)
      end
    end
    consume instruments

actor InitialNbboFileGenerator
  let _env: Env
  let _auth: AmbientAuth
  let _output_file_path: String
  embed _wb: Writer = Writer
  let _number_generator: RandomNumberGenerator = RandomNumberGenerator
  let _time: (I64 val, I64 val) = Time.now()
  var _rejected_instruments: Array[InstrumentData val] val
  var _nonrejected_instruments: Array[InstrumentData val] val
  var _utc_timestamp: String


  new create(env: Env,
    auth: AmbientAuth,
    output_file_path: String,
    rejected_instruments: Array[InstrumentData val] val,
    nonrejected_instruments: Array[InstrumentData val] val)
  =>
    _env = env
    _auth = auth
    _output_file_path = output_file_path
    _rejected_instruments = rejected_instruments
    _nonrejected_instruments = nonrejected_instruments
    let date = Date(_time._1, _time._2)
    _utc_timestamp = date.format("%Y%m%d-%H:%M:%S.000")

  be generate_and_write() =>
    generate_nbbo_messages(_rejected_instruments, true)
    generate_nbbo_messages(_nonrejected_instruments, false)
    write_to_file()

  be generate_nbbo_messages(instruments: Array[InstrumentData val] val,
    reject: Bool)
  =>
    for instrument in instruments.values() do
      let fix_nbbo_msg =
        RandomFixNbboGenerator(instrument, _number_generator,
        reject, _utc_timestamp)
      let nbbo_string = FixMessageStringify.nbbo(fix_nbbo_msg)
      _wb.write(nbbo_string)
    end

  be write_to_file() =>
    try
      let output_file = File(FilePath(_auth, _output_file_path))
      output_file.set_length(0)
      output_file.writev(_wb.done())
    end
