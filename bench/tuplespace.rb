# Benchmark the default tuplespace (which is not intended to be fast).

module Tupelo
  class Client; end
end

require 'tupelo/client/tuplespace'
require 'benchmark'

N_TUPLES = 100_000
N_DELETES = 10_000

Benchmark.bm(20) do |b|
  ts = Tupelo::Client::SimpleTuplespace.new

  b.report('insert') do
    N_TUPLES.times do |i|
      ts.insert i
    end
  end
  
  b.report('delete') do
    N_DELETES.times do
      i = rand(N_TUPLES)
      if ts.delete_once i
        ts.insert i
      end
    end
  end
end
