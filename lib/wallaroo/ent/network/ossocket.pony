/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

Copyright (C) 2016-2018, The Pony Developers
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use @pony_os_errno[I32]()

primitive OSSockOpt
  fun sol_socket(): I32 =>
    ifdef osx then
      65535
    else
    ifdef linux then
      1
    else
    ifdef freebsd then
      65535
    else
    ifdef windows then
      0
    else
      0
    end
    end
    end
    end

  fun so_rcvbuf(): I32 =>
    ifdef osx then
      4098
    else
    ifdef linux then
      8
    else
    ifdef freebsd then
      4098
    else
    ifdef windows then
      0
    else
      0
    end
    end
    end
    end

  fun so_sndbuf(): I32 =>
    ifdef osx then
      4097
    else
    ifdef linux then
      7
    else
    ifdef freebsd then
      4097
    else
    ifdef windows then
      0
    else
      0
    end
    end
    end
    end

primitive OSSocket

  fun get_so_rcvbuf(fd: U32): (U32, U32) =>
    """
    Wrapper for the FFI call `getsockopt(fd, SOL_SOCKET, SO_RCVBUF, ...)`
    """
    getsockopt_u32(fd, OSSockOpt.sol_socket(), OSSockOpt.so_rcvbuf())

  fun get_so_sndbuf(fd: U32): (U32, U32) =>
    """
    Wrapper for the FFI call `getsockopt(fd, SOL_SOCKET, SO_SNDBUF, ...)`
    """
    getsockopt_u32(fd, OSSockOpt.sol_socket(), OSSockOpt.so_sndbuf())

  fun set_so_rcvbuf(fd: U32, bufsize: U32): U32 =>
    """
    Wrapper for the FFI call `setsockopt(fd, SOL_SOCKET, SO_RCVBUF, ...)`
    """
    setsockopt_u32(fd, OSSockOpt.sol_socket(), OSSockOpt.so_rcvbuf(), bufsize)

  fun set_so_sndbuf(fd: U32, bufsize: U32): U32 =>
    """
    Wrapper for the FFI call `setsockopt(fd, SOL_SOCKET, SO_SNDBUF, ...)`
    """
    setsockopt_u32(fd, OSSockOpt.sol_socket(), OSSockOpt.so_sndbuf(), bufsize)

  fun getsockopt_u32(fd: U32, level: I32, option_name: I32): (U32, U32) =>
    """
    Wrapper for sockets to the `getsockopt(2)` system call where
    the kernel's returned option value is a C `uint32_t` type / Pony
    type `U32`.

    In case of system call success, this function returns the 2-tuple:
    1. The integer `0`.
    2. The `*option_value` returned by the kernel converted to a Pony `U32`.

    In case of system call failure, this function returns the 2-tuple:
    1. The value of `errno`.
    2. An undefined value that must be ignored.
    """
    (let errno: U32, let buffer: Array[U8] iso) =
      get_so(fd, level, option_name, 4)

    if errno == 0 then
      try
          (errno, bytes4_to_u32(consume buffer)?)
      else
        (1, 0)
      end
    else
      (errno, 0)
    end

  fun setsockopt_u32(fd: U32, level: I32, option_name: I32, option: U32): U32 =>
    """
    Wrapper for sockets to the `setsockopt(2)` system call where
    the kernel expects an option value of a C `uint32_t` type / Pony
    type `U32`.

    This function returns `0` on success, else the value of `errno` on
    failure.
    """
    var word: Array[U8] ref = u32_to_bytes4(option)
    set_so(fd, level, option_name, word)

  fun get_so(fd: U32, level: I32, option_name: I32, option_max_size: USize): (U32, Array[U8] iso^) =>
    """
    Low-level interface to `getsockopt(2)`.

    In case of system call success, this function returns the 2-tuple:
    1. The integer `0`.
    2. An `Array[U8]` of data returned by the system call's `void *`
       4th argument.  Its size is specified by the kernel via the
       system call's `sockopt_len_t *` 5th argument.

    In case of system call failure, `errno` is returned in the first
    element of the 2-tuple, and the second element's value is junk.
    """
    var option: Array[U8] iso = recover option.create().>undefined(option_max_size) end
    var option_size: USize = option_max_size
    let result: I32 = @getsockopt[I32](fd, level, option_name,
       option.cpointer(), addressof option_size)

    if result == 0 then
      option.truncate(option_size)
      (0, consume option)
    else
      option.truncate(0)
      (@pony_os_errno().u32(), consume option)
    end

  fun set_so(fd: U32, level: I32, option_name: I32, option: Array[U8]): U32 =>
    var option_size: U32 = option.size().u32()
    """
    Low-level interface to `setsockopt(2)`.

    This function returns `0` on success, else the value of `errno` on
    failure.
    """
    let result: I32 = @setsockopt[I32](fd, level, option_name,
       option.cpointer(), option_size)

    if result == 0 then
      0
    else
      @pony_os_errno().u32()
    end

  fun bytes4_to_u32(b: Array[U8]): U32 ? =>
    if true then // ifdef littleendian
      (b(3)?.u32() << 24) or (b(2)?.u32() << 16) or (b(1)?.u32() << 8) or b(0)?.u32()
    else
      (b(0)?.u32() << 24) or (b(1)?.u32() << 16) or (b(2)?.u32() << 8) or b(3)?.u32()
    end

  fun u32_to_bytes4(option: U32): Array[U8] =>
    if true then // ifdef littleendian
      [ (option and 0xFF).u8(); ((option >> 8) and 0xFF).u8()
        ((option >> 16) and 0xFF).u8(); ((option >> 24) and 0xFF).u8() ]
    else
      [ ((option >> 24) and 0xFF).u8(); ((option >> 16) and 0xFF).u8()
        ((option >> 8) and 0xFF).u8(); (option and 0xFF).u8() ]
    end
