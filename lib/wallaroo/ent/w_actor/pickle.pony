/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "buffered"
use "serialise"
use "net"
use "collections"
use "crypto"
use "random"
use "sendence/rand"

primitive Pickle
  fun apply[S: Any #read](s: S, auth: AmbientAuth): ByteSeq val ? =>
    Serialised(SerialiseAuth(auth), s).output(OutputSerialisedAuth(auth))

  fun md5_digest(data: ByteSeq): String =>
    ToHexString(Digest.md5().>append(data).final())

primitive Unpickle
  fun apply[S: Any #read](data: ByteSeq val, auth: AmbientAuth): S ? =>
    try
      match Serialised.input(InputSerialisedAuth(auth), data as Array[U8] val)(
        DeserialiseAuth(auth))
      | let s: S => s
      else
        error
      end
    else
      error
    end
