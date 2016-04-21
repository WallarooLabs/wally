interface CSVVisitor
  fun ref apply(values: Array[String] ref): None ?

class CSVReader
  fun ref parse(input: String, visitor: CSVVisitor ref, fs: String = ",", ls: String = "\n") ? =>
    let lines: Array[String] = input.split(ls)
    for l in lines.values() do
      if l != "" then
        let values: Array[String] ref = l.split(fs)
        visitor(values)
      end
    end
