require 'tupelo/app'

N = 3

Tupelo.application do |app|
  app.child do |client| # the lock manager
    loop do
      client.write ["resource", "none"]
      lock_id, client_id, duration = client.read ["resource", nil, nil]
      sleep duration
      client.take [lock_id, client_id, duration]
        # optimization: combine take and write in a transaction, just to
        # reduce delay
    end
    # exercise for reader: make this work with 2 or more resources
    # exercise: rewrite this with hash tuples instead of array tuples
  end
  
  N.times do |i|
    app.child do |client|
      client.transaction do |t|
        t.take ["resource", "none"]
        t.write ["resource", client.client_id, 0.5]
      end
      # Thundering herd -- all N clients can respond at the same time.
      # A better example would have a queue -- see lock-mgr-with-queue.rb.
      
      10.times do |j|
        # Now we are ouside of transaction, but still no other client may use
        # "resource" until lock expires (or is otherwise removed), as long
        # as all clients follow the read protocol below.
        sleep 0.2

        client.transaction do |t|
          t.read ["resource", client.client_id, nil]
          t.write ["c#{client.client_id}##{j}"]
        end
      end
    end
  end
  
  app.child do |client|
    # This client never even tries to lock the resource, so it cannot write.
    client.transaction do |t|
      t.read ["resource", client.client_id, nil]
      t.write ["c#{client.client_id}##{j}"]
    end
    client.log.error "should never get here"
  end
end
