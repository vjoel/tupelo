require 'tupelo/app'

N = 100

Tupelo.application do |app|
  app.child do |client|
    N.times do
      client.transaction do |t|
        x, y = t.take [nil, nil]
        sleep rand/100
        t.write [x+1, y]
      end
    end
    client.write ["done"]
  end

  app.child do |client|
    N.times do
      client.transaction do |t|
        x, y = t.take [nil, nil]
        sleep rand/100
        t.write [x, y+1]
      end
    end
    client.write ["done"]
  end

  app.local do |client|
    client.write [0, 0]

    2.times do
      client.take ["done"]
    end

    x, y = client.read [nil, nil]
    if x == N and y == N
      puts "OK"
    else
      abort "FAIL: x=#{x}, y=#{y}"
    end
  end
end
