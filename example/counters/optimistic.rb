require 'tupelo/app'

N_PROCS = 3
N_ITER = 10

Tupelo.application do
  pids = N_PROCS.times.map do
    child do
      N_ITER.times do
        transaction do
          c = take count: nil
          write count: c["count"] + 1
        end
        sleep 0.1
      end
    end
  end
  
  local do
    write count: 0
      # we have to make sure we write this initial counter only once,
      # which is easy in this case, but not always. See merge.rb for
      # an approach that allows multiple initializations.
    
    pids.each {|pid| Process.waitpid pid}
      # could also use tuples to do this
    log read count: nil
  end
end
