require 'tupelo/app'
require 'benchmark'

N = 1000

Tupelo.application do |app|
  app.local do |client|
    Benchmark.bmbm(20) do |b|
      GC.start
      b.report('nowait') do
        1000.times do
          client.pulse_nowait [0]
        end
      end

      GC.start
      b.report('wait') do
        1000.times do
          client.pulse_wait [0]
        end
      end
    end
  end
end

