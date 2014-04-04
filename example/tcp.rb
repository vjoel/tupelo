# Most examples in this dir use unix sockets for simplicity. With a little
# more effort, you can switch to tcp for remote access.
#
# Run this file like:
#
#  ruby tcp.rb --info
#
# or
#
#  ruby tcp.rb --trace
#
# You can test with a local client:
#
#   ../bin/tup tcp.yaml
#
# Copy tcp.yaml to a remote host.
#
# Then run a client like this:
#
#   bin/tup remote-copy-of-tcp.yaml
#
# If you have ssh set up, you don't even need to copy the file. Just reference
# it in the same way you would with scp:
#
#   bin/tup host:tcp.yaml

require 'tupelo/app'

sv = "tcp.yaml" # copy this file to remote clients, setting host as needed
port = 9901 # Use 0 to let system choose free port

Tupelo.application services_file: sv,
            seqd_addr:  {proto: :tcp, bind_host: '0.0.0.0', port: port},
            cseqd_addr: {proto: :tcp, bind_host: '0.0.0.0', port: port + 1},
            arcd_addr:  {proto: :tcp, bind_host: '0.0.0.0', port: port + 2} do
  if owns_services
    puts "service started; ^C to stop"
    puts "run in another terminal: ../bin/tup tcp.yaml"
    if log.level > Logger::INFO
      puts "(run with --info or --trace to see events)"
    end
    sleep
  else
    abort "service seems to be running already; check file #{sv.inspect}"
  end
end
