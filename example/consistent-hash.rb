# TODO make more interesting by changing the set of workers over time.

require 'tupelo/app'
require 'tupelo/util/bin-circle'

N_BINS = 5
N_REPS = 30 # of each bin, to make distribution more uniform
N_ITER = 1000

Tupelo.application do
  local do
    use_subspaces!

    N_BINS.times do |id|
      define_subspace id, [id, Numeric, Numeric]
    end

    define_subspace "sum", ["sum", Numeric, Numeric, Numeric]
  end

  circle = BinCircle.new

  N_BINS.times do |id|
    circle.add_bin id, reps: N_REPS
  end

  N_BINS.times do |id|
    child subscribe: [id], passive: true do
      # take things belonging to the process's bin
      count = 0
      at_exit {log "load: #{count}"}

      loop do
        _, n1, n2 = take [id, Numeric, Numeric]
          # could use take {|| ...} to optimistically start long computation
        write ["sum", n1, n2, n1+n2]
        count += 1
      end

      # the following loop is faster, but not horiz. scalable
      if false
        read [id, Numeric, Numeric] do |_, n1, n2|
          write ["sum", n1, n2, n1+n2]
          count += 1
        end
      end
    end
  end
  
  local subscribe: ["sum"] do
    srand(12345)

    Thread.new do
      N_ITER.times do  |i|
        ns = [rand(100), rand(100)]
        bin_id = circle.find_bin(ns)
        write [bin_id, *ns]
      end
    end
    
    N_ITER.times do |i|
      _, n1, n2, sum = take ["sum", Numeric, Numeric, Numeric]
      unless n1 + n2 == sum
        log.error "bad sum"
      end
      q,r = (100*(i+1)).divmod N_ITER
      if r == 0
        printf "\r%3d%", q
      end
    end
    puts
  end
end
