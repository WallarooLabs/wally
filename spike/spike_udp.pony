use "net"

class Notifier is UDPNotify
  let _env: Env
  let _out_addr: IPAddress
  let _out_sock: UDPSocket
  let _processor: Processor

  new create(env: Env, out_ip: String, out_port: String, processor: Processor) ? =>
    _env = env
    _out_addr = DNS.ip4(out_ip, out_port)(0)
    _out_sock = UDPSocket.ip4(recover Forwarder(env) end)
    _processor = processor

  fun ref listening(sock: UDPSocket ref) =>
    try
      let ip = sock.local_address()
      (let host, let service) = ip.name()
      _env.out.print("spike: listening on " + host + ":" + service)
    else
      _env.out.print("spike: couldn't get local name")
      sock.dispose()
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("spike: not listening")
    sock.dispose()

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: IPAddress) =>
    let d: Array[U8] val = consume data
    let cp: Array[U8] iso = recover iso d.clone() end
    try
      let payload: Array[U8] iso = BuffyProtocol.decode(consume cp)

      _env.out.print("RECEIVING")
      try
        (let host, let service) = from.name()
        _env.out.print("from " + host + ":" + service)
      end

      _env.out.print(consume payload)
      _processor.spike(d, _out_sock, _out_addr, _env)
      sock.write("got it", from)
    end

  fun ref closed(sock: UDPSocket ref) =>
    _env.out.print("spike: closed")

class Forwarder is UDPNotify
  let _env: Env

  new create(env: Env) =>
    _env = env

  fun ref listening(sock: UDPSocket ref) =>
    try
      let ip = sock.local_address()
      (let host, let service) = ip.name()
    else
      _env.out.print("spike-output: couldn't get local name")
      sock.dispose()
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    _env.out.print("spike-output: not listening")
    sock.dispose()

  fun ref closed(sock: UDPSocket ref) =>
    _env.out.print("spike: closed")