require 'tupelo/app'

N = 2
K = 1

Tupelo.application do
  (N+K).times do
    child do
      catch :gave_up do
        tries = 0

        r = take [Integer] do |val|
          tries += 1
          if tries >= N
            log "giving up on #{val}"
            throw :gave_up
          end
          log "trying to take #{val}"
        end

        log "took #{r.inspect}"
      end
    end
  end
  
  sleep 0.01

  child do
    N.times do |i|
      write [i]
      log "wrote #{[i]}"
      sleep 0.1
    end
  end
end
