require 'tupelo/app'

N_PROCS = 3
N_ITER = 10

Tupelo.application do
  pids = N_PROCS.times.map do
    child do
      N_ITER.times do
        write count: 1
        sleep 0.1
      end
    end
  end
  
  local do
    # note: no need to init counter
    pids.each {|pid| Process.waitpid pid}

    # but we cannot read the counter(s) without first merging them
    # see also example/dedup.rb
    while transaction do
      c1 = take_nowait count: nil
      c2 = take_nowait count: nil
      if c1 and c2
        write count: c1["count"] + c2["count"]
        true
      elsif c1
        log c1
      else
        log count: 0
      end
    end
  end
end
