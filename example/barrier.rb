# Unlike MPI barriers, does not use token ring. This is better for loosely
# coupled systems -- a failed process doesn't break the ring, the state is in
# the distributed tuplespace rather than just one process, and a replacement
# process can be swapped in. Run with --trace to see what's happening.

require 'tupelo/app'

N_WORKERS = 5
N_STEPS = 3

Tupelo.application do
  pids = []
  N_WORKERS.times do |wi|
    pids << child do
      N_STEPS.times do |si|
        sleep 0.1 # do some work
        
        write step: si, worker: wi

        N_WORKERS.times do |i|
          read step: si, worker: i
        end
      end
    end
  end
  
  pids.each {|pid| Process.wait pid}
  puts "done"
end
