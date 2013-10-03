# Use ruby's timeout lib to time out a read. For transactions there is also
# the timeout parameter (which is more efficient). See timeout-trans.rb.

require 'tupelo/app'

Tupelo.application do
  child do
    begin
      n_sec = 2
      Timeout.timeout n_sec do
        log "waiting for non-existing tuple #{[0]}"
        read [0]
      end
    rescue TimeoutError
      log "stopped waiting"
    end
    
    r = read [1]
    log "got #{r}"
  end

  child do
    sleep 1
    log "writing [1]"
    write [1]
  end
end

