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
    sleep 0.3

    src = take(name: "alice", balance: Numeric)
    dst = take(name: "bob", balance: Numeric)

    if src["balance"] < 500
      abort "insufficient funds -- not attempting transfer"
    end

    sleep 0.3
      # Even though we are outside of transaction, the delay doesn't matter,
      # since this process possesses the tuples. So there is no failure.
      # However, this has some disadvantages compared to the transaction
      # implementation in the other examples: it's not atomic, tuples might
      # be lost if the client exits, and more network hops (latency).
    
    src = src.dup
    dst = dst.dup

    src["balance"] -= 500
    dst["balance"] += 500

    w = write src, dst
    log "attempting to set #{[src, dst]}"

    w.wait
    log read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
