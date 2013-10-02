# Run this with --trace to see that, even in the FAIL case, take_nowait never
# hangs waiting for a match. The "ready" tuple is just to keep the take
# requests fairly close in time, increasing the chance of transaction failure.
# Exactly one of the contending clients will take the tuple.

require 'tupelo/app'

Tupelo.application do
  20.times do
    child do
      read ["ready"]
      r = take_nowait [1]
      log "winner! result = #{r.inspect}" if r
    end
  end

  local do
    write [1]
    write ["ready"]
  end
end
