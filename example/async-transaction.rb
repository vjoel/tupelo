require 'tupelo/app'

# see also cancel.rb

Tupelo.application do |app|
  app.child do |client|
    t = client.transaction.async do |t|
      t.write ["pong"]
      t.take ["ping"]
    end
    
    client.write ["ping"]
    puts client.take ["pong"]
    puts t.value
  end
end
