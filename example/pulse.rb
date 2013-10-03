# See pubsub.rb for a more interesting use of pulse.

require 'tupelo/app'

Tupelo.application do
  child do
    take ['start']
    10.times do |i|
      pulse [i]
      sleep 0.1
    end
    write ['finish']
  end
  
  child do
    Thread.new do
      loop do
        log read [Integer]
        log read_all [Integer]
      end
    end
    
    write ['start']
    take ['finish']
  end
end
