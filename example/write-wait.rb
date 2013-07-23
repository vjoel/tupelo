require 'tupelo/app'

Tupelo.application do |app|
  app.local do |client|
    client.write [1]
    client.write [2]
    w = client.write [3]
    p client.read_all [nil]
    w.wait # wait for the write to come back and be applied to the client
    p client.read_all [nil]

    client.write [4]
    client.write [5]
    client.write_wait [6]
    p client.read_all [nil]
  end
end
