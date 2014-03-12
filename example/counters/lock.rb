require 'tupelo/app'

N_PROCS = 3
N_ITER = 10

Tupelo.application do
  pids = N_PROCS.times.map do
    child do
      N_ITER.times do
        c = take count: nil
          # unlike optimistic.rb, a system/network failure here
          # could cause this tuple to be lost. To safeguard: example/lease.rb
        write count: c["count"] + 1
        sleep 0.1
      end
    end
  end
  
  local do
    write count: 0
    pids.each {|pid| Process.waitpid pid}
    log read count: nil
  end
end
