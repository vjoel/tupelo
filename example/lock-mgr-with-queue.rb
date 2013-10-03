# This is like lock-mgr.rb, but by using a queue, we avoid the thundering herd
# problem. You can observe this by seeing "FAILED" in the output of the former
# but not in the latter. This means that competing offers are resolved by the
# queue, rather than by propagating them to all clients.
#
# Run with --trace

require 'tupelo/app'

N = 3

Tupelo.application do
  child passive: true do # the lock manager
    log.progname << " (lock mgr)"
    waiters = Queue.new

    Thread.new do
      loop do
        _, _, client_id, duration =
          take ["request", "resource", nil, nil]
        waiters << [client_id, duration]
      end
    end

    loop do
      client_id, duration = waiters.pop
      write ["resource", client_id, duration]
      begin
        take ["done", "resource", client_id], timeout: duration
      rescue TimeoutError
        log "forcing client #{client_id} to stop using resource."
      end
      take ["resource", client_id, duration]
    end
    # exercise for reader: make this work with 2 or more resources
    # exercise: rewrite this with hash tuples instead of array tuples
  end
  
  N.times do |i|
    child do
      write ["request", "resource", client_id, 0.5]
      
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
