require 'tupelo/app'

svr = "tiny-server.yaml"

Tupelo.application servers_file: svr do
  if owns_servers
    abort "server not running"
  end

  child do
    write ["Hello", "world!"]
    p take [nil, nil]
  end
end
