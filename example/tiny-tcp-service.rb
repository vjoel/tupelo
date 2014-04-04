# Run this with a specified filename: 
#
#   ruby tiny-tcp-service.rb srv.yaml
#
# Then you can run the client locally:
#
#   ruby tiny-tcp-client.rb srv.yaml
#
# or from a remote host that can ssh back to the server
#
#   ruby tiny-tcp-client.rb serverhost:path/to/srv.yaml
#
# (Use the --tunnel switch to send the data over ssh, as well.)
#
# You can also access the service using tup:
#
#   tup srv.yaml
#   >> w [12, 34]
#   >> r [12, 34, nil]
#   => [12, 34, 46]

require 'tupelo/app'

Tupelo.tcp_application do
  puts "service started"
  local do
    loop do
      x, y = take [Numeric, Numeric]
      write [x, y, x+y]
    end
  end
end
