interface MessageFileParser
"""
The MessageFileParser interface provides default methods for splitting a block 
of input text into an array of Strings, which can overridden by a subclass.
"""
  fun ref apply(values: Array[String] ref) ?

  fun ls(): (String|None) =>
  """
  Line separator. Use None to avoid splitting on lines.
  """
    "\n"

  fun ln(): USize =>
  """
  Maximum parts for the line split. (See String.split for more information.)
  """
    0

  fun fs(): (String|None) =>
  """
  Field separator. Use None to avoid splitting on fields.
  """
    ","

  fun fn(): USize =>
  """
  Maximum parts for the field split. (See String.split for more information.)
  """
    0

class MessageFileReader
  fun ref apply(input: String, parser: MessageFileParser ref) ? =>
  """
  The apply method separates an input String based on the methods provided in
  the parser.
  If parser.ls() returns a String, that string will be used to split the text
  into lines, with parser.ln(): USize given as a parameter to the split()
  function.

  If parser.fs() returns a String, that string will be used to split each line
  into fields, with parser.fn(): USize given as a parameter to the split
  function.
  This is useful when you only want to split the line into two parts, and where
  the field separator may appear multiple times in the second field (e.g. a
  comma in a sentence).
  """
    var cur_line_number: USize = 0
    var cur_line: String = ""
    match parser.ls()
    | let ls: String =>  // split the input into lines
        let lines: Array[String] = input.split(ls, parser.ln())
        match parser.fs()
        | let fs: String =>  // split each line into fields
            try
              for l in lines.values() do
                cur_line_number = cur_line_number + 1
                cur_line = l
                let values: Array[String] ref = l.split(fs, parser.fn())
                if values.size() > 0 then
                  parser(values)
                end
              end
            else
              @printf[I32](("Failed reading on line " 
                + cur_line_number.string() + ":\n").cstring())
              @printf[I32]((cur_line + "\n").cstring())
              error
            end
        else  // no field separator, return the parser over the entire line
          for l in lines.values() do
            parser(recover ref [l] end)
          end
        end
    else  // No line separator, return the parser over the entire input
      parser(recover ref [input] end)
    end
