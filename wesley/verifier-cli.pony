use "ini"
use "files"

primitive Usage
  fun message(command: String): String val => "Usage: ".add(command).add(" SENT-FILE RECEIVED-FILE match|nomatch|TEST-INI-FILE")

interface SetupError
  fun exitcode(): I32 => 0
  fun message(): String => ""

class SetupErrorWrongArgs is SetupError
  let _message: String val
  new create(command: String) =>
    _message = Usage.message(command)
  fun exitcode(): I32 => 90
  fun message(): String => _message

class SetupErrorExpectedMatchInvalid
  let _message: String
  new create(expected_match: String) =>
    _message = "Error: Expected match was '".add(expected_match).add("', must be one of: match nomatch TEST-INI-FILE")
  fun exitcode(): I32 => 91
  fun message(): String => _message

class SetupErrorCouldNotFindMatchStatusInFile
  let _message: String val
  new create(file_name: String) =>
    _message = "Error: Could not find section '[test_config]' with property 'expected_result' in file '".add(file_name).add("'.")
  fun exitcode(): I32 => 92
  fun message(): String => _message

class SetupErrorProblemReadingCSV
  let _message: String val
  new create(file_name: String) =>
    _message = "Error: Problem reading CSV file '".add(file_name).add("'.")
  fun exitcode(): I32 => 93
  fun message(): String => _message

primitive VerifierCLI
  fun _parse_args(args: Array[String] val): (String, String, String, String) ? =>
    if args.size() == 4 then
       (args(0), args(1), args(2), args(3))
    else
      error
    end

  fun _get_expected_match_status_from_string(expected_match_result_str: String): (MatchStatus val | String) =>
    match expected_match_result_str
    | "match" => ResultsMatch
    | "nomatch" => ResultsDoNotMatch
    else
      expected_match_result_str
    end

  fun _read_expected_match_status_file(file_name: String, root: (AmbientAuth | None)): IniMap ? =>
    var test_ini: IniMap = IniMap
    let caps = recover val FileCaps.set(FileRead).set(FileStat) end
    with file = OpenFile(FilePath(root as AmbientAuth, file_name, caps)) as File do
      test_ini = IniParse(file.lines())
    end
    test_ini

  fun _get_expected_match_status_value(test_ini: IniMap): MatchStatus val ? =>
    let test_config = test_ini("test_config")
    let expected_result = test_config("expected_result")
    match expected_result
    | "match" => ResultsMatch
    | "nomatch" => ResultsDoNotMatch
    else
      error
    end

  fun _read_csv_file_with_visitor(file_name: String, visitor: CSVVisitor, root: (AmbientAuth | None)): None ? =>
    let caps = recover val FileCaps.set(FileRead).set(FileStat) end
    with file = OpenFile(FilePath(root as AmbientAuth, file_name, caps)) as File do
      CSVReader.parse(file.read_string(file.size()), visitor)
    else
      error
    end

  fun run(env: Env, result_mapper: ResultMapper, sent_visitor: SentVisitor, received_visitor: ReceivedVisitor) =>
    match verifier_from_command_line(env, result_mapper, sent_visitor, received_visitor)
    | let verifier: Verifier => verify(env, verifier)
    | let setup_error: SetupError =>
      env.exitcode(setup_error.exitcode())
      env.err.print(setup_error.message())
    end

  fun verifier_from_command_line(env: Env, result_mapper: ResultMapper, sent_visitor: SentVisitor, received_visitor: ReceivedVisitor): (SetupError | Verifier) =>
    (let prog: String, let sent_file: String, let received_file: String, let expectation_str: String) = try
      _parse_args(env.args)
    else
      return SetupErrorWrongArgs(try env.args(0) else "???" end)
    end

    let expected_match_result: MatchStatus val = try
      match _get_expected_match_status_from_string(expectation_str)
      | let m: MatchStatus val => m
      | let ini_file_name: String =>
        let test_ini: IniMap = _read_expected_match_status_file(expectation_str, env.root)
        try
          _get_expected_match_status_value(test_ini)
        else
          return SetupErrorCouldNotFindMatchStatusInFile(ini_file_name)
        end
      else
        error
      end
    else
      return SetupErrorExpectedMatchInvalid(expectation_str)
    end

    try
      _read_csv_file_with_visitor(sent_file, sent_visitor, env.root)
    else
      return SetupErrorProblemReadingCSV(sent_file)
    end

    try
      _read_csv_file_with_visitor(received_file, received_visitor, env.root)
    else
      return SetupErrorProblemReadingCSV(received_file)
    end

    Verifier(sent_visitor.build_sent_messages(), received_visitor.build_received_messages(), result_mapper, expected_match_result)

  fun verify(env:Env, verifier: Verifier ref): None =>
    let pass_fail = verifier.test()
    env.err.print(pass_fail.exitmessage())
    env.exitcode(pass_fail.exitcode())
