require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    done = false
    until done do
      client.transaction do |t|
        op, x, y = t.take [String, Numeric, Numeric]
        # further operations within this transaction can depend on the above.
        
        case op
        when "+"
          t.write [op, x, y, x + y]
        when "*"
          t.write [op, x, y, x * y]
        when "select"
          _, _, _, z = t.take [nil, nil, nil, x..y]
          t.write [op, x, y, z]
        when "stop"
          done = true
        end
      end
    end
  end

  app.child do |client|
    client.write ["+", 1, 2]
    results = client.read ["+", 1, 2, nil]
    p results

    client.write ["*", 3, 4]
    results = client.read ["*", 3, 4, nil]
    p results

    client.write ["select", 10, 20]
    p client.read ["select", 10, 20, nil]
    
    client.write ["stop", 0, 0]
  end
end
