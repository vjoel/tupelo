require 'tupelo/app'

N = 100

Tupelo.application do
  child do
    write [0, 0]

    t1 = Thread.new do
      N.times do
        transaction do
          take ["reader ready"]
          x, y = take [nil, nil]
          write [x+1, y]
          write ["data ready"]
        end
      end
    end
    
    t2 = Thread.new do
      N.times do
        transaction do
          take ["reader ready"]
          x, y = take [nil, nil]
          write [x, y+1]
          write ["data ready"]
        end
      end
    end
    
    loop do
      write ["reader ready"]
      take ["data ready"]
      x, y = read [nil, nil]
      log "%3d %3d" % [x, y]
      break if x == N and y == N
    end
  end
end
