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

    # The next block of code reads the "current value" of the counter.
    #
    # "Current" means globally correct as of the last global
    # tick received at the local client.
    #
    # The "value" of the counter is defined to be the sum of all n
    # occurring in some tuple matching {count: nil}.
    #
    # The difficulty is that we cannot read the counter without
    # first merging all the matching count tuples. In a sense, this
    # is like CRDTs in an eventually consistent DB.
    #
    # See also example/dedup.rb.
    log "merging..." while transaction do
      c1 = take_nowait count: nil
      c2 = take_nowait count: nil
      if c1 and c2
        write count: c1["count"] + c2["count"]
        true
          # We had to merge, so try again.
      elsif c1
        log c1
          # At the tick of the second take_nowait, exactly one count
          # tuple exists, so we can safely report that value as the
          # global count, with the understanding that the count
          # may have changed at a later tick (even by the time the
          # transaction commits).
        false
      else
        log count: 0
          # At the time of this txn, no count tuple exists.
        false
      end
    end
  end
end
