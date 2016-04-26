interface CSVVisitor
"""
The CSVVisitor interface provides default methods for splitting a block of input
text into an array of Strings, which can overridden by a subclass.
"""
  fun ref apply(values: Array[String] ref): None ?

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



class CSVReader
  fun ref parse(input: String, visitor: CSVVisitor ref) ? =>
  """
  The parse method separates an input String based on the methods provided in
  the visitor.
  If visitor.ls() returns a String, that string will be used to split the text
  into lines, with visitor.ln(): USize given as a parameter to the split()
  function.

  If visitor.fs() returns a String, that string will be used to split each line
  into fields, with visitor.fn(): USize given as a parameter to the split
  function.
  This is useful when you only want to split the line into two parts, and where
  the field separator may appear multiple times in the second field (e.g. a
  comma in a sentence).
  """
    match visitor.ls()
    | let ls: String =>  // split the input into lines
        let lines: Array[String] = input.split(ls, visitor.ln())
        match visitor.fs()
        | let fs: String =>  // split each line into fields
            for l in lines.values() do
              let values: Array[String] ref = l.split(fs, visitor.fn())
              if values.size() > 0 then
                visitor(values)
              end
            end
        else  // no field separator, return the visitor over the entire line
          for l in lines.values() do
            visitor(recover ref [l] end)
          end
        end
    else  // No line separator, return the visitor over the entire input
      visitor(recover ref [input] end)
    end
