require 'tupelo/app'

N = 2
K = 1

Tupelo.application do |app|
  (N+K).times do
    app.child do |client|
      catch :gave_up do
        tries = 0

        r = client.take [Integer] do |val|
          tries += 1
          if tries >= N
            client.log "giving up on #{val}"
            throw :gave_up
          end
          client.log "trying to take #{val}"
        end

        client.log "took #{r.inspect}"
      end
    end
  end
  
  sleep 0.01

  app.child do |client|
    N.times do |i|
      client.write [i]
      client.log "wrote #{[i]}"
      sleep 0.1
    end
  end
end
