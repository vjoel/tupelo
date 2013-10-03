require 'tupelo/app'

Tupelo.application do
  child do
    write(
      {name: "alice", balance: 1000},
      {name: "bob", balance: 200}
    )
    10.times do |i|
      alice = take(name: "alice", balance: Numeric)
      log alice
      alice = alice.dup
      alice["balance"] -= 10
      write_wait alice
      sleep 0.1
    end
    
    log read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
  
  child do
    transaction do
      src = take(name: "alice", balance: Numeric)
      dst = take(name: "bob", balance: Numeric)

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
      
      log "attempting to set #{[src, dst]}"
      write src, dst

      if false # enable this to see how failures are retried
        begin
          commit.wait
        rescue => ex
          log "retrying after #{ex}"
          raise
        end
      end
    end
    
    log read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
