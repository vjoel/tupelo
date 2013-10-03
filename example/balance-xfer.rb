require 'tupelo/app'

Tupelo.application do
  child do
    write(
      {name: "alice", balance: 1000},
      {name: "bob", balance: 200}
    )
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

      write src, dst
    end
    # transaction will block if balances have changed since the read.
    # see balance-xfer-retry.rb
    
    log read_all(name: /^(?:alice|bob)$/, balance: nil)
  end
end
