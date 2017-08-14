class val InitFile
  let filename: String
  let msg_size: (USize | None)

  new val create(fname: String, msize: (USize | None) = None) =>
    filename = fname
    msg_size = msize
