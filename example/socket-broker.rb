# Tuples are not well suited to streaming data or very large data, but they
# can be used to coordinate access to such data.

require 'tupelo/app'

Tupelo.application do
  child passive: true do
    loop do
      _, key = take ["session-request", nil]

      serv = TCPServer.new 0
      host = serv.addr[2]
      port = serv.addr[1]

      fork do
        sock = serv.accept
        sock.send "lots of data at #{Time.now}", 0
        sleep 1
        sock.send "lots more data at #{Time.now}", 0
      end

      write_wait ["session-response", key, host, port]
    end
  end
  
  2.times do
    child do
      key = client_id
        # use client_id here just because we know it is unique to this client

      write ["session-request", key]
      _, _, host, port = take ["session-response", key, nil, nil]

      sock = TCPSocket.new host, port
      loop do
        msg = sock.recv(1000)
        break if msg.size == 0
        log msg
      end
    end
  end
end
