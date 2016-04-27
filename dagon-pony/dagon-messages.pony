use "osc-pony"

primitive DagonMessageTypes
  // [0] tell supervisor we're ready to accept work
  fun ready(): I32    => 0
  // [1] tell supervisor we're done with work
  fun done(): I32     => 1
  // [2] tell a node to initiate shutdown procedures
  fun shutdown(): I32 => 2
  // [3] tell supervisor (dagon) that shutdown succeeded
  fun done_shutdown(): I32     => 3
     
primitive DagonMessageEncoder
  fun ready(): Array[U8] val =>
    let osc = OSCMessage("/dagon", recover [as OSCData val:
      OSCInt(DagonMessageTypes.ready())] end)
      Bytes.encode_osc(osc)
      
  fun done(): Array[U8] val =>
    let osc = OSCMessage("/dagon", recover [as OSCData val:
      OSCInt(DagonMessageTypes.done())] end)
      Bytes.encode_osc(osc)

  fun shutdown(): Array[U8] val =>
    let osc = OSCMessage("/dagon", recover [as OSCData val:
      OSCInt(DagonMessageTypes.shutdown())] end)
      Bytes.encode_osc(osc)

  fun done_shutdown(): Array[U8] val =>
    let osc = OSCMessage("/dagon", recover [as OSCData val:
      OSCInt(DagonMessageTypes.done_shutdown())] end)
      Bytes.encode_osc(osc)
