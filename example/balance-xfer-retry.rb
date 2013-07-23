require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write(
      {name: "alice", balance: 1000},
      {name: "bob", balance: 200}
    )
    10.times do |i|
      alice = client.take(name: "alice", balance: Numeric)
      client.log alice
      alice = alice.dup
      alice["balance"] -= 10
      client.write_wait alice
      sleep 0.1
    end
    
    client.log client.read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
  
  app.child do |client|
    client.transaction do |t|
      src = t.take(name: "alice", balance: Numeric)
      dst = t.take(name: "bob", balance: Numeric)

      if src["balance"] < 500
        abort "insufficient funds -- not attempting transfer"
      end

      src = src.dup
      dst = dst.dup

      src["balance"] -= 500
      dst["balance"] += 500
      
      sleep 0.3
        # force fail -- the tuples this client is trying to take
        # will be gone when it wakes up
      
      client.log "attempting to set #{[src, dst]}"
      t.write src, dst

      if false # enable this to see how failures are retried
        begin
          t.commit.wait
        rescue => ex
          client.log "retrying after #{ex}"
          raise
        end
      end
    end
    
    client.log client.read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
