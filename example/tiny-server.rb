require 'tupelo/app'

svr = "tiny-server.yaml"

Tupelo.application servers_file: svr do |app|
  if app.owns_servers
    puts "server started"
    sleep
  else
    abort "server seems to be running already; check file #{svr.inspect}"
  end
end
