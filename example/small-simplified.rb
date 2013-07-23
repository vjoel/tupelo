# Same as small.rb, but with the generic setup code factored out.

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write [2, 3, "frogs"]
    _, s = client.take ["animals", nil]
    puts s
  end

  app.child do |client|
    x, y, s = client.take [Numeric, Numeric, String]
    s2 = ([s] * (x + y)).join(" ")
    client.write ["animals", s2]
  end
end

