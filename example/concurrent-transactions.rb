require 'tupelo/app'

N = 100

Tupelo.application do |app|
  app.child do |client|
    client.write [0, 0]

    t1 = Thread.new do
      N.times do
        client.transaction do |t|
          t.take ["reader ready"]
          x, y = t.take [nil, nil]
          t.write [x+1, y]
          t.write ["data ready"]
        end
      end
    end
    
    t2 = Thread.new do
      N.times do
        client.transaction do |t|
          t.take ["reader ready"]
          x, y = t.take [nil, nil]
          t.write [x, y+1]
          t.write ["data ready"]
        end
      end
    end
    
    loop do
      client.write ["reader ready"]
      client.take ["data ready"]
      x, y = client.read [nil, nil]
      client.log "%3d %3d" % [x, y]
      break if x == N and y == N
    end
  end
end
