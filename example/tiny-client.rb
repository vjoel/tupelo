require 'tupelo/app'

svr = "tiny-server.yaml"

Tupelo.application servers_file: svr do |app|
  if app.owns_servers
    abort "server not running"
  end

  app.child do |client|
    client.write ["Hello", "world!"]
    p client.take [nil, nil]
  end
end
