# This is like lock-mgr.rb, but by using a queue, we avoid the thundering herd
# problem. You can observe this by seeing "FAILED" in the output of the former
# but not in the latter. This means that competing offers are resolved by the
# queue, rather than by propagating them to all clients.

require 'tupelo/app'

N = 3

Tupelo.application do |app|
  app.child do |client| # a debugger client, to see what's happening
    note = client.notifier
    puts "%4s %4s %10s %s" % %w{ tick cid status operation }
    loop do
      status, tick, cid, op = note.wait
      unless status == :attempt
        s = status == :failure ? "FAILED" : ""
        puts "%4d %4d %10s %p" % [tick, cid, s, op]
      end
    end
  end
  
  app.child do |client| # the lock manager
    client.log.progname << " (lock mgr)"
    waiters = Queue.new

    Thread.new do
      loop do
        _, _, client_id, duration =
          client.take ["request", "resource", nil, nil]
        waiters << [client_id, duration]
      end
    end

    loop do
      client_id, duration = waiters.pop
      client.write ["resource", client_id, duration]
      begin
        client.take ["done", "resource", client_id], timeout: duration
      rescue TimeoutError
        client.log "forcing client #{client_id} to stop using resource."
      end
      client.take ["resource", client_id, duration]
    end
    # exercise for reader: make this work with 2 or more resources
    # exercise: rewrite this with hash tuples instead of array tuples
  end
  
  N.times do |i|
    app.child do |client|
      client.write ["request", "resource", client.client_id, 0.5]
      
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
