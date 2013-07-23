require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    ats = (0..4).map do |i|
      client.transaction.async do |t|
        t.take ["start"]
        t.write [i]
      end
    end
    
    [0,1,2,4].each {|i| ats[i].cancel}

    client.write ["start"]
    p client.take [Integer]
  end
end
