require 'tupelo/app'

Tupelo.application do
  local do
    begin
      val = transaction timeout: 0.1 do
        write [1]
        read [1] # similarly for take
      end
      p val # should be [1]
    rescue TimeoutError => ex
      puts ex
    end
  end
end
