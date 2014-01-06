require 'tupelo/app'
require 'digest/md5'
require 'rbtree'

N_BINS = 5
N_REPLS = 50 # of each bin, to make distibution more uniform
KEY_BITS = 30
KEY_MAX = 2**KEY_BITS - 1

def show_bins circle
#  p circle
  bin_size = Array.new(N_BINS, 0)
  bin_size[circle.first[1]] = 2**30 - circle.last[0] + circle.first[0]
  circle.each_cons(2) do |(prev, _), (key, i_bin)|
    bin_size[i_bin] += key - prev
  end
  p bin_size ## variance
end

Tupelo.application do
  srand(12345)
  circle = MultiRBTree.new

  N_BINS.times do |i_bin|
    N_REPLS.times do |i_repl|
      id = "bin #{i_bin}, repl #{i_repl}"
      key = Digest::MD5.hexdigest(id).to_i(16) & KEY_MAX
      circle[key] = i_bin
    end
  end

  show_bins(circle); exit

  N_BINS.times do |i_bin|
    child passive: true do
      # take things belonging to the repls of i_bin on circle
      # use custom tuplespace to pre-sort
    end
  end
end
