# Same as small.rb, but with the generic setup code factored out.

require 'tupelo/app'

Tupelo.application do
  child do
    write [2, 3, "frogs"]
    _, s = take ["animals", nil]
    puts s
  end

  child do
    x, y, s = take [Numeric, Numeric, String]
    s2 = ([s] * (x + y)).join(" ")
    write ["animals", s2]
  end
end

