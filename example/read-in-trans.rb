require 'tupelo/app'

Thread.abort_on_exception = true

N = 5

Tupelo.application do
  N.times do |i|
    child do
      Thread.new do
        step = 0
        loop do
          step += 1
          transaction do
            read ["enabled", i]
            write ["output", i, step]
          end
          sleep 0.2
        end
      end
      
      read ["done"]
      exit
    end
  end
  
  child do
    t = Thread.new do
      loop do
        msg, i, step = take [nil, nil, nil]
        printf "%20s from %2d at step %3d\n", msg, i, step
      end
    end

    puts "Turning on 0 and 4"
    write ["enabled", 0]
    write ["enabled", 4]
    sleep 2
    
    puts "Turning off 0"
    take ["enabled", 0]
    sleep 2
    
    puts "Turning off 4"
    take ["enabled", 4]
    sleep 2
    
    puts "Turning on 1 and 3"
    write ["enabled", 1]
    write ["enabled", 3]
    sleep 2
    
    puts "Bye!"
    write ["done"]
  end
end
