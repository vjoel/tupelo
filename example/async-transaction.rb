require 'tupelo/app'

# see also cancel.rb

Tupelo.application do
  child do
    t = transaction.async do
      write ["pong"]
      take ["ping"]
    end
    
    write ["ping"]
    puts take ["pong"]
    puts t.value
  end
end
