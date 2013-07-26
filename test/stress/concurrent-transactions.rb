require 'tupelo/app'
require 'tupelo/app/monitor'
require 'time-fuzz'

N = 100
VERBOSE = ARGV.delete "-v"

client_class = Tupelo::TimeFuzz::Client
Tupelo::TimeFuzz.sleep_max = 0.01

Tupelo.application do |app|
  app.start_monitor if VERBOSE

  app.child(client_class) do |client|
    N.times do
      client.transaction do |t|
        x, y = t.take [nil, nil]
        t.write [x+1, y]
      end
    end
    client.write ["done"]
  end

  app.child(client_class) do |client|
    N.times do
      client.transaction do |t|
        x, y = t.take [nil, nil]
        t.write [x, y+1]
      end
    end
    client.write ["done"]
  end

  app.local(client_class) do |client|
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
