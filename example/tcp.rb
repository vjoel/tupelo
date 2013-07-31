# Most examples in this dir use unix sockets for simplicity. With a little
# more effort, you can switch to tcp for remote access.
#
# Run this file like:
#
#  ruby tcp.rb --info
#
# or
#
#  ruby tcp.rb --monitor
#
# You can test with a local client:
#
#   ../bin/tup tcp.yaml
#
# Copy tcp.yaml to a remote host, and in the remote copy edit the
# addr field to a hostname (or ip addr) isntead of 0.0.0.0.
#
# Then run a client like this:
#
#   bin/tup remote-copy-of-tcp.yaml

require 'tupelo/app'

svr = "tcp.yaml" # copy this file to remote clients, setting host as needed
port = 9901 # Use 0 to let system choose free port

Tupelo.application servers_file: svr,
            seqd_addr:  [:tcp, '0.0.0.0', port],
            cseqd_addr: [:tcp, '0.0.0.0', port + 1],
            arcd_addr:  [:tcp, '0.0.0.0', port + 2] do |app|
  if app.owns_servers
    puts "server started; ^C to stop"
    puts "run in another terminal: ../bin/tup tcp.yaml"
    if app.log.level > Logger::INFO
      puts "(run with --info or --monitor to see events)"
    end
    sleep
  else
    abort "server seems to be running already; check file #{svr.inspect}"
  end
end
