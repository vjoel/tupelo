require 'tupelo/app'

N = 50

Tupelo.application do
  N.times do |i|
    sleep i/1000.0
    child do
      write [1]
    end
  end
end
