require 'tupelo/app'

Tupelo.application do
  child do
    write [1]
    sleep 0.1
    take [1]
    write [2]
  end
  
  child do
    final_i =
      take([Integer]) do |optimistic_i|
        log "optimistic_i = #{optimistic_i}"
        sleep 0.2
      end
    
    log "final_i = #{final_i}"
  end
end
