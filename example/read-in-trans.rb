require 'tupelo/app'

Thread.abort_on_exception = true

N = 5

Tupelo.application do |app|
  N.times do |i|
    app.child do |client|
      Thread.new do
        step = 0
        loop do
          step += 1
          client.transaction do |t|
            t.read ["enabled", i]
            t.write ["output", i, step]
          end
          sleep 0.2
        end
      end
      
      client.read ["done"]
      exit
    end
  end
  
  app.child do |client|
    t = Thread.new do
      loop do
        msg, i, step = client.take [nil, nil, nil]
        printf "%20s from %2d at step %3d\n", msg, i, step
      end
    end

    puts "Turning on 0 and 4"
    client.write ["enabled", 0]
    client.write ["enabled", 4]
    sleep 2
    
    puts "Turning off 0"
    client.take ["enabled", 0]
    sleep 2
    
    puts "Turning off 4"
    client.take ["enabled", 4]
    sleep 2
    
    puts "Turning on 1 and 3"
    client.write ["enabled", 1]
    client.write ["enabled", 3]
    sleep 2
    
    puts "Bye!"
    client.write ["done"]
  end
end
