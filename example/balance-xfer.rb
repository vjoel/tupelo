require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write(
      {name: "alice", balance: 1000},
      {name: "bob", balance: 200}
    )
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

      t.write src, dst
    end
    # transaction will block if balances have changed since the read.
    # see balance-xfer-retry.rb
    
    client.log client.read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
