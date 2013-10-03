require 'tupelo/app'

Tupelo.application do
  child do
    done = false
    until done do
      transaction do
        op, x, y = take [String, Numeric, Numeric]
        # further operations within this transaction can depend on the above.
        
        case op
        when "+"
          write [op, x, y, x + y]
        when "*"
          write [op, x, y, x * y]
        when "select"
          _, _, _, z = take [nil, nil, nil, x..y]
          write [op, x, y, z]
        when "stop"
          done = true
        end
      end
    end
  end

  child do
    write ["+", 1, 2]
    results = read ["+", 1, 2, nil]
    p results

    write ["*", 3, 4]
    results = read ["*", 3, 4, nil]
    p results

    write ["select", 10, 20]
    p read ["select", 10, 20, nil]
    
    write ["stop", 0, 0]
  end
end
