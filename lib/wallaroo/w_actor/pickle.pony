use "buffered"
use "serialise"
use "net"
use "collections"
use "crypto"
use "random"
use "sendence/rand"

primitive Pickle
  fun apply[S: Any #read](s: S, auth: AmbientAuth): Array[U8] val ?
  =>
    Serialised(SerialiseAuth(auth), s).output(OutputSerialisedAuth(auth))

  fun md5_digest(data: ByteSeq): String =>
    ToHexString(Digest.md5().>append(data).final())

primitive Unpickle
  fun apply[S: Any #read](data: Array[U8] val, auth: AmbientAuth): S ? =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data)(
        DeserialiseAuth(auth))
      | let s: S => s
      else
        error
      end
    else
      error
    end
