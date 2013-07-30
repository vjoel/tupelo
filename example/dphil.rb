# Dining philosopher example, based on:
#
# http://www.lindaspaces.com/book/chap9.htm

require 'tupelo/app'

N_PHIL = 5
N_ITER = 10

Tupelo.application do
  N_PHIL.times do |i|
    child do
      log.progname << ": phil #{i}"
      write ["eat", i, 0] # amount eaten

      N_ITER.times do
        # lock the resource:
        ticket = take ["room ticket"]
        c0 = take ["chopstick", i]
        c1 = take ["chopstick", (i+1)%N_PHIL]
        
        # use the resource:
        _,_,count = take ["eat", i, nil]
        write ["eat", i, count+1]

        # release the resource:
        write c0, c1, ticket
      end
      
      log "ate #{read(["eat", i, nil])[2]}"
    end
  end
  
  local do
    N_PHIL.times do |i|
      write ["chopstick", i]
    end
    (N_PHIL-1).times do
      write ["room ticket"]
    end
  end
end
