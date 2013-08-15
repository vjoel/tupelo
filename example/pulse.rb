# See pubsub.rb for a more interesting use of pulse.

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.take ['start']
    10.times do |i|
      client.pulse [i]
      sleep 0.1
    end
    client.write ['finish']
  end
  
  app.child do |client|
    Thread.new do
      loop do
        client.log client.read [Integer]
        client.log client.read_all [Integer]
      end
    end
    
    client.write ['start']
    client.take ['finish']
  end
end
