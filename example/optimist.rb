require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write [1]
    sleep 0.1
    client.take [1]
    client.write [2]
  end
  
  app.child do |client|
    final_i =
      client.take([Integer]) do |optimistic_i|
        client.log "optimistic_i = #{optimistic_i}"
        sleep 0.2
      end
    
    client.log "final_i = #{final_i}"
  end
end
