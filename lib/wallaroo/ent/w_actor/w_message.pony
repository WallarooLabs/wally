/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

class WMessage
  let sender: U128
  let receiver: U128
  let payload: Any val

  new val create(s: U128, r: U128, p: Any val) =>
    sender = s
    receiver = r
    payload = p
