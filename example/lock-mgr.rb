# Run with --trace

require 'tupelo/app'

N = 3

Tupelo.application do
  child passive: true do # the lock manager
    log.progname << " (lock mgr)"
    loop do
      write ["resource", "none"]
      lock_id, client_id, duration = read ["resource", nil, nil]
      sleep duration
      take [lock_id, client_id, duration]
        # optimization: combine take and write in a transaction, just to
        # reduce delay
    end
    # exercise for reader: make this work with 2 or more resources
    # exercise: rewrite this with hash tuples instead of array tuples
  end
  
  N.times do |i|
    child do
      transaction do
        take ["resource", "none"]
        write ["resource", client_id, 0.5]
      end
      # Thundering herd -- all N clients can respond at the same time.
      # Can be avoided with a queue -- see lock-mgr-with-queue.rb.
      
      2.times do |j|
        # Now we are ouside of transaction, but still no other client may use
        # "resource" until lock expires (or is otherwise removed), as long
        # as all clients follow the read protocol below.
        sleep 0.2

        transaction do
          read ["resource", client_id, nil]
          write ["c#{client_id}##{j}"]
        end
      end
    end
  end
  
  child passive: true do
    # This client never even tries to lock the resource, so it cannot write.
    transaction do
      read ["resource", client_id, nil]
      write ["c#{client_id}##{j}"]
    end
    log.error "should never get here"
  end
end
