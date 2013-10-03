require 'tupelo/app'
require 'time-fuzz'

N = 100

client_class = Tupelo::TimeFuzz::Client
Tupelo::TimeFuzz.sleep_max = 0.01

Tupelo.application do
  child(client_class) do
    N.times do
      transaction do
        x, y = take [nil, nil]
        write [x+1, y]
      end
    end
    write ["done"]
  end

  child(client_class) do
    N.times do
      transaction do
        x, y = take [nil, nil]
        write [x, y+1]
      end
    end
    write ["done"]
  end

  local(client_class) do
    write [0, 0]

    2.times do
      take ["done"]
    end

    x, y = read [nil, nil]
    if x == N and y == N
      puts "OK"
    else
      abort "FAIL: x=#{x}, y=#{y}"
    end
  end
end
