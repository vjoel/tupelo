require 'tupelo/app'

Tupelo.application do |app|
  2.times do
    app.child do |client|
      begin
        # the block is re-executed for the client that fails to take [1]
        # this is also true in the transaction do...end construct.
        t = client.transaction
        r = t.take [Integer]
        client.log "trying to take #{r.inspect}"
        t.commit.wait
        client.log "took #{r.inspect}"
      rescue Tupelo::Client::TransactionFailure => ex
        client.log "#{ex} -- retrying"
        retry
        # manually emulate the effect of transaction do...end
      end
    end
  end
  
  app.child do |client|
    client.write [1]
    client.log "wrote #{[1]}"
    sleep 0.1
    client.write [2]
    client.log "wrote #{[2]}"
  end
end
