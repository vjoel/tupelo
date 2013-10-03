require 'tupelo/app'

Tupelo.application do
  2.times do
    child do
      begin
        # the block is re-executed for the client that fails to take [1]
        # this is also true in the transaction do...end construct.
        t = transaction
        r = t.take [Integer]
        log "trying to take #{r.inspect}"
        t.commit.wait
        log "took #{r.inspect}"
      rescue Tupelo::Client::TransactionFailure => ex
        log "#{ex} -- retrying"
        retry
        # manually emulate the effect of transaction do...end
      end
    end
  end
  
  child do
    write [1]
    log "wrote #{[1]}"
    sleep 0.1
    write [2]
    log "wrote #{[2]}"
  end
end
