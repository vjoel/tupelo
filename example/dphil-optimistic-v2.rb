# Dining philosopher example. Like dphil-optimistic.rb, but replaces
# each take-write pair with a read. Same effect, inside a transaction,
# and it is a little faster.

require 'tupelo/app/dsl'

N_PHIL = 5
N_ITER = 10

Tupelo::DSL.application do
  N_PHIL.times do |i|
    child do
      log.progname << ": phil #{i}"
      write ["eat", i, 0] # amount eaten

      N_ITER.times do
        transaction do
          # lock the resource (in transaction, so optimistically):
          read ["chopstick", i]
          read ["chopstick", (i+1)%N_PHIL]

          # use the resource:
          _,_,count = take ["eat", i, nil]
          write ["eat", i, count+1]
        end
      end
      
      log "ate #{read(["eat", i, nil])[2]}"
    end
  end
  
  local do
    N_PHIL.times do |i|
      write ["chopstick", i]
    end
  end
end
