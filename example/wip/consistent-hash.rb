require 'tupelo/app'
require 'digest/md5'
require 'rbtree'

N_BINS = 5
N_REPLS = 50 # of each bin, to make distibution more uniform

Tupelo.application do
  srand(12345)
  circle = MultiRBTree.new

  N_BINS.times do |i_bin|
    N_REPLS.times do |i_repl|
      id = "bin #{i_bin}, repl #{i_repl}"
      key = Digest::MD5.hexdigest(id).to_i(16) % 2**30
      circle[key] = i_bin
    end
  end

if false
#  p circle
  bin_size = Array.new(N_BINS, 0)
  prev = 0
  first = nil
  circle.each do |key, i_bin|
    first ||= i_bin
    bin_size[i_bin] += key - prev
    prev = key
  end
  bin_size[first] += 2**30 - prev
  p bin_size
end

  N_BINS.times do |i_bin|
    child do
      # take things belonging to the repls of i_bin on circle
    end
  end
end
