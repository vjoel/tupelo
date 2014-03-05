require 'rbtree'

## TODO
##
## generalize SortedSetSpace to accept params that indicate which fields
##   are key and value
##
## unify with space used in ../riemann v2, generalize

# This is a template class, but it doesn't just match tuples. It can
# be used to find the *next* tuple after a given one, using the rbtree
# ordering.
class SortedSetTemplate
  class << self
    alias [] new
  end
  
  # cmd can be "next", "prev", "first", "last"
  # for next/prev, args is [key]
  # for first/last, args is empty
  def initialize tag, cmd, *args
    @tag = tag
    @cmd = cmd
    @args = args
  end
  
  def find_in tree, distinct_from: []
    # for simplicity, ignore distinct_from
    # -- we never take/read multiple keys in the tree
    case @cmd
    when "first"
      k, v = tree.first
      k && [@tag, k, v.first]
    when "last"
      tree.last
      k && [@tag, k, v.last]
    when "prev"
      k = @args[0]
      (k1,v1),(k2,v2) = tree.bound(tree.first[0], k).last(2)
        ## Bad rbtree! This will be much less efficient than "next".
      if k == k2
        k1 && [@tag, k1, v1.last]
      else
        k2 && [@tag, k2, v2.last]
      end
      ## anomaly: can't iterate through multivalues
    when "next"
      k = @args[0]
      (k1,v1),(k2,v2) = tree.bound(k, tree.last[0]).first(2)
        ## Bad rbtree! There is no bounded search with < (rather than <=)
      if k == k1
        k2 && [@tag, k2, v2.first]
      else
        k1 && [@tag, k1, v1.first]
      end
    else
      raise "bad command"
    end
  end
end

# A tuple store (in-memory) that is optimized for (key_string, object) pairs.
# The object may be any serializable object (built up from numbers, booleans,
# nil, strings, hashes and arrays).
#
# By default, multiple values per key are allowed. (This differs from a typical
# key-value store, in wihch a given key_string may occur only once.)
# It is up to the application to decide whether to enforce key uniqueness or
# not (for example, by taking (k,...) before writing (k,v).
#
# This store should be used only by clients that subscribe to a subspace
# that can be represented as triples (tag, key_string, value), where
# the tag is a single literal value that is the same for all triples.
# (See memo2.rb.)
#
# This store also manages command and meta tuples, which it keeps in an array,
# just like the default Tuplespace class does.
class SortedSetSpace
  include Enumerable

  attr_reader :tag, :tree, :metas

  def initialize tag
    @tag = tag
    clear
  end

  def clear
    @tree = RBTree.new{|t,k| t[k] = []}
      # It's up to the application to enforce one entry per key.
    @metas = []
      # We are automatically subscribed to tupelo metadata (subspace defs), so
      # we need to keep them somewhere. Also, the command tuples.
  end

  def each
    tree.each do |k, vs|
      vs.each do |v|
        yield [tag, k, v]
      end
    end
    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    if tuple.kind_of? Array and tuple.size == 3 and
       tuple[0] == tag and tuple[1].kind_of? String

      _, k, v = tuple
      tree[k] << v

    else
      metas << tuple
    end
  end

  def delete_once tuple
    if tuple.kind_of? Array and tuple.size == 3 and
       tuple[0] == tag and tuple[1].kind_of? String

      _, k, v = tuple
      if tree.key?(k) and tree[k].include? v
        tree[k].delete v
        tree.delete k if tree[k].empty?
        true
      else
        false
      end

    else
      if i=metas.index(tuple)
        metas.delete_at i
      end
    end
  end

  def transaction inserts: [], deletes: [], tick: nil
    deletes.each do |tuple|
      delete_once tuple or raise "bug"
    end

    inserts.each do |tuple|
      insert tuple.freeze ## should be deep_freeze
    end
  end

  def find_distinct_matches_for templates
    templates.inject([]) do |tuples, template|
      tuples << find_match_for(template, distinct_from: tuples)
    end
  end

  def find_match_for template, distinct_from: []
    case template
    when SortedSetTemplate
      template.find_in tree, distinct_from: distinct_from
    else
      # fall back to linear search
      find do |tuple|
        template === tuple and not distinct_from.any? {|t| t.equal? tuple}
      end
    end
  end
end
