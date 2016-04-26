interface CSVVisitor
  fun ref apply(values: Array[String] ref): None ?
  fun ls(): (String|None) => "\n"
  fun ln(): USize => 0
  fun fs(): (String|None) => ","
  fun fn(): USize => 0


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
