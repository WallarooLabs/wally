use "collections"
use "files"


trait val TestReaderWriterBuilder
  fun apply(): TestReaderWriter

trait TestReaderWriter
  fun ref expect(n: USize)
  fun ref try_read(): (ByteSeq iso^ | None)
  fun ref write(bs: ByteSeq val)

class val FileTestReaderWriterBuilder is TestReaderWriterBuilder
  let _r_file_path: FilePath
  let _w_file_path: FilePath

  new val create(r_file_path: FilePath, w_file_path: FilePath) =>
    _r_file_path = r_file_path
    _w_file_path = w_file_path

  fun apply(): TestReaderWriter =>
    FileTestReaderWriter(File.open(_r_file_path), File(_w_file_path))

class FileTestReaderWriter is TestReaderWriter
  let read_buf: Array[U8] = read_buf.create()
  let read_amounts: Array[USize] = read_amounts.create()
  var leftover: USize = 0

  // let write_buf: Array[ByteSeq val] = write_buf.create()
  // let write_max: USize
  // var bytes_written: USize = 0

  let _r_file: File
  let _w_file: File

  new create(r_file: File, w_file: File) =>
    _r_file = r_file
    _w_file = w_file

  fun ref expect(n: USize) =>
    read_amounts.push(n)

    // Try to read any bytes we still haven't been able to read
    if leftover > 0 then
      let next_bytes = _r_file.read(leftover)
      let bytes_read = next_bytes.size()
      for b in (consume next_bytes).values() do
        read_buf.push(b)
      end
      leftover = leftover - bytes_read
    end

    // Try to read the bytes just requested
    let next_bytes = _r_file.read(n)
    let bytes_read = next_bytes.size()
    for b in (consume next_bytes).values() do
      read_buf.push(b)
    end
    leftover = leftover + (n - bytes_read)

  fun ref try_read(): (ByteSeq iso^ | None) =>
    // If there are enough bytes in read_buf for the next read amount, return them.
    if read_amounts.size() > 0 then
      try
        let next_read_amount = read_amounts(0)?
        if read_buf.size() >= next_read_amount then
          let ret = recover iso Array[U8] end
          for _ in Range(0, next_read_amount) do
            ret.push(read_buf.shift()?)
          end
          read_amounts.shift()?
          consume ret
        else
          None
        end
      else
        None
      end
    else
      None
    end

  // fun ref write_again() =>
  fun ref write(bs: ByteSeq val) =>
    _w_file.write(bs)

  fun ref dispose() =>
    _r_file.dispose()
    _w_file.dispose()
