require 'tupelo/app/dsl'
require 'tupelo/app/monitor'

N = 50

Tupelo::DSL.application do
  #start_monitor
  child do
    10.times do
      write [1]
    end
  end

  N.times do |i|
    sleep i/1000.0
    child do
      write [1]
    end
  end
end
