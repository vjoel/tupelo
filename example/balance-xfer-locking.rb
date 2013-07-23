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
    sleep 0.3

    src = client.take(name: "alice", balance: Numeric)
    dst = client.take(name: "bob", balance: Numeric)

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

    w = client.write src, dst
    client.log "attempting to set #{[src, dst]}"

    w.wait
    client.log client.read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
