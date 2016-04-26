interface CSVVisitor
"""
The CSVVisitor interface provides default methods for splitting a block of input
text into an array of Strings, which can overridden by a subclass.
"""
  fun ref apply(values: Array[String] ref): None ?

  fun ls(): (String|None) => "\n"
  """
  Line separator. Use None to avoid splitting on lines.
  """

  fun ln(): USize => 0
  """
  Maximum parts for the line split. (See String.split for more information.)
  """

  fun fs(): (String|None) => ","
  """
  Field separator. Use None to avoid splitting on fields.
  """

  fun fn(): USize => 0
  """
  Maximum parts for the field split. (See String.split for more information.)
  """



class CSVReader
  fun ref parse(input: String, visitor: CSVVisitor ref) ? =>
    match visitor.ls()
    | let ls: String =>
        let lines: Array[String] = input.split(ls, visitor.ln())
        match visitor.fs()
        | let fs: String =>
            for l in lines.values() do
              let values: Array[String] ref = l.split(fs, visitor.fn())
              if values.size() > 0 then
                visitor(values)
              end
            end
        else
          for l in lines.values() do
            visitor(recover ref [l] end)
          end
        end
    else
      visitor(recover ref [input] end)
    end
