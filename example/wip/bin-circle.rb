require 'rbtree' # gem install rbtree
require 'set'
require 'digest/md5'

# Used to determine which bin a given object is
# associated with. For example: use it to look up which distributed cache
# the object is stored in. Does not store or cache any data.
# The state of a BinCircle instance depends entirely on two things:
# the replications number (either provided as default_reps in BinCircle#new
# or set per bin in #add_bin), and the current set of bins, which is managed
# with #add_bin and #delete_bin.
# Note: like rbtree, not thread-safe (for #delete and #show_bins).
# https://en.wikipedia.org/wiki/Consistent_hashing
class BinCircle
  KEY_BITS = 30
  KEY_MAX = 2**KEY_BITS - 1
  DEFAULT_REPS = 10
  
  attr_accessor :default_reps

  def initialize reps: DEFAULT_REPS
    @tree = MultiRBTree.new # hashed_bin_id => bin_id
    @default_reps = reps
  end
  
  # +id+ should be an identifier for your bin, typically a number or string.
  # Uses id.to_s, so +id+ should not contain a hash (which would not determine
  # a unique string).
  def add_bin id, reps: default_reps
    rep_id = "#{id} 0000"
    reps.times do |i|
      key = key_for_string(rep_id)
      @tree[key] = id
      rep_id.succ!
    end
  end
  
  # Returns the set of bin ids now in the circle.
  def bins
    Set.new @tree.values
  end
  
  # This hashing fn is applied to both bin ids and object identifiers (in
  # principle, these could be two different function with the same range of
  # outputs.
  def key_for_string str
    Digest::MD5.hexdigest(str).to_i(16) & KEY_MAX
  end
  
  def delete_bin id
    @tree.delete_if {|k,v| v == id}
  end
  
  # +id+ should be an identifier for your object, typically a number or string.
  # Uses id.to_s, so +id+ should not contain a hash (which would not determine
  # a unique string). It is not necessary for +id+ to be unique across objects.
  def find_bin obj
    find_bin_by_key(key_for_string(obj.to_s))
  end
  
  def find_bin_by_key key
    _, id = @tree.lower_bound(key) || @tree.first
    id
  end

  def bin_size
    Hash.new(0).tap do |bs|
      bs[@tree.first[1]] = 2**30 - @tree.last[0] + @tree.first[0]
      @tree.each_cons(2) do |(prev, _), (key, id)|
        bs[id] += key - prev
      end
    end
  end

  # To help in tuning the replication counts, you can look at the
  # distribution of bin sizes, plus mean and variance.
  def show_bins
    bs = bin_size
    p bs

    mean = bs.inject(0.0) {|sum, (id,n)| sum + n} / N_BINS
    variance = bs.inject(0.0) {|sum_sqerr, (id,n)|
      sum_sqerr + (n - mean)**2} / (N_BINS-1)
    printf "mean : %14d\n" % mean
    printf "stdev: %14d\n" % Math.sqrt(variance)
  end
end

if __FILE__ == $0
  N_BINS = 100
  N_REPS = 20

  circle = BinCircle.new reps: N_REPS

  N_BINS.times do |id|
    circle.add_bin id
  end

  p circle.bins
  circle.show_bins

  p circle.find_bin "foo"
  p circle.find_bin "bar"
end
