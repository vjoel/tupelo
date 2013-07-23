# Use ruby's timeout lib to time out a read. For transactions there is also
# the timeout parameter (which is more efficient). See timeout-trans.rb.

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    begin
      n_sec = 2
      Timeout.timeout n_sec do
        client.log "waiting for non-existing tuple #{[0]}"
        client.read [0]
      end
    rescue TimeoutError
    end
    
    r = client.read [1]
    client.log "got #{r}"
  end

  app.child do |client|
    sleep 1
    client.log "writing [1]"
    client.write [1]
  end
end

