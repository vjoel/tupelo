# Dining philosopher example. Like dphil-optimistic.rb, but replaces
# each take-write pair with a read. Same effect, inside a transaction,
# and it is a little faster.

require 'tupelo/app/dsl'
require 'tupelo/app/monitor'

N_PHIL = 5
N_ITER = 10
VERBOSE = ARGV.delete "-v"

Tupelo::DSL.application do
  start_monitor if VERBOSE

  N_PHIL.times do |i|
    child do
      log.progname << ": phil #{i}"
      write ["eat", i, 0] # amount eaten

      N_ITER.times do
        transaction do
          # lock the resource (in transaction, so optimistically):
          c0 = read ["chopstick", i]
          c1 = read_nowait ["chopstick", (i+1)%N_PHIL]
          fail! unless c1 # try again (unlikely, but possible)

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
