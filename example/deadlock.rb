# See the README reference to this file.
# Run with --trace to see what's happening.

require 'tupelo/app'

def observe_deadlock
  done = false
  at_exit do
       # for a passive client, exit is forced when there are no
       # more non-passive clients
    if done
      log "done (should not happen)"
    else
      log "stopped in deadlock (as expected)"
    end
  end

  yield  

  done = true
end

Tupelo.application do
  local do
    write [1], [2], [3], [4]
  end
  
  child passive: true do
    observe_deadlock do
      take [1]
      sleep 1
      take [2]
      write [1], [2]
    end
  end

  child passive: true do
    observe_deadlock do
      sleep 0.5
      take [2]
      take [1]
      write [1], [2]
    end
  end

  child do
    transaction do
      take [3]
      sleep 1
      take [4]
      write [3], [4]
      log "done"
    end
  end

  child do
    transaction do
      sleep 0.5
      take [4]
      take [3]
      write [3], [4]
      log "done"
    end
  end

end
