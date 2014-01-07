require 'tupelo/app'
require_relative 'bin-circle'

N_BINS = 5
N_REPS = 30 # of each bin, to make distribution more uniform

Tupelo.application do
  srand(12345)
  circle = BinCircle.new

  N_BINS.times do |id|
    circle.add_bin id, reps: N_REPS
  end

  circle.show_bins; exit

  N_BINS.times do |id|
    child passive: true do
      # take things belonging to the repls of i_bin on circle
      # use custom tuplespace to pre-sort
      loop do
        #take proc {|key
      end
    end
  end
end
