require 'tupelo/app'

Tupelo.application do |app|
  app.local do |client|
    begin
      val = client.transaction timeout: 0.1 do |t|
        t.write [1]
        t.read [1] # similarly for take
      end
      p val # should be [1]
    rescue TimeoutError => ex
      puts ex
    end
  end
end
