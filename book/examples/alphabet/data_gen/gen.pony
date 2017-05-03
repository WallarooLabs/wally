use "collections"
use "options"
use "random"
use "time"
use "buffered"
use "files"

actor Main
  let letters: Array[String] =
  "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z".split(",")

  new create(env: Env) =>
    let options = Options(env.args)
    var file_path = "votes.msg"
    var message_count: I32 = 0

    options
      .add("output", "o", StringArgument)
      .add("message-count", "m", I64Argument)

    for option in options do
      match option
      | ("output", let arg: String) => file_path = arg
      | ("message-count", let arg: I64) => message_count = arg.i32()
      end
    end

    try
      let auth = env.root as AmbientAuth

      let wb: Writer = Writer

      let rand = MT(Time.nanos())

      let file = File(FilePath(auth, file_path))

      if message_count == 0 then
        env.out.print("Please specify a message count (--message-count/-m)")
        error
      end

      for idx in Range[I32](0, message_count) do
        let next_vote = rand.int(100).u32()
        let next_letter = try
          letters(rand.int(letters.size().u64()).usize())
        else
          "."
        end

        file.writev(VoteEncoder(next_letter, next_vote, wb))
      end

      file.dispose()
    end

primitive VoteEncoder
  fun apply(letter: String, count: U32, wb: Writer = Writer): Array[ByteSeq] val
  =>
    // Header
    wb.u32_be(5)
    // Fields
    wb.write(letter)
    wb.u32_be(count)
    wb.done()
