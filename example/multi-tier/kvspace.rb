# A tuple store (in-memory) that is optimized for (key_string, object) pairs.
# The object may be any serializable object (built up from numbers, booleans,
# nil, strings, hashes and arrays).
#
# Unlike in a key-value store, a given key_string may occur more than once.
# It is up to the application to decide whether to enforce key uniqueness or
# not (for example, by taking (k,...) before writing (k,v).
#
# This store should be used only by clients that subscribe to a subspace
# that can be represented as pairs. (See memo2.rb.)
#
# Important: a client using this as its tuplespace should never #write a tuple.
# (However, it may accept a #write from another client.) The problem is that we
# don't store subspace metadata and so there is no way to classify and tag
# outgoing tuples.
class KVSpace
  include Enumerable

  attr_reader :tag, :hash

  def initialize tag
    @tag = tag
    clear
  end

  def clear
    @hash = Hash.new {|h,k| h[k] = []}
      # it's up to the application to enforce that these arrays have size <=1
  end

  def each
    hash.each do |k, vs|
      vs.each do |v|
        yield tag, k, v
      end
    end
  end

  def insert tuple
    case tuple
    when Hash # can only be meta tuple
      raise ArgumentError unless tuple.key? "__tupelo__" ## is_meta?
      # do nothing: this client never writes, so it doesn't need this info

    when Array
      #raise ArgumentError unless tuple.size == 3 ## subscribe works
      t, k, v = tuple
      #raise ArgumentError unless t == tag and k.kind_of? String ## ditto

      hash[k] << v

    else
      raise ArgumentError
    end
  end

  def delete_once tuple
    case tuple
    when Hash # can only be meta tuple
      raise ArgumentError unless tuple.key? "__tupelo__" ## is_meta?
      true ### better not to get these tuples (or keep them in another ts?)
        ### otherwise we might mistakenly accept a transaction
      # do nothing: this client never writes, so it doesn't need this info

    when Array
      #raise ArgumentError unless tuple.size == 3 ## subscribe works
      t, k, v = tuple
      #raise ArgumentError unless t == tag and k.kind_of? String ## ditto

      if hash.key?(k) and hash[k].include? v
        hash[k].delete v
        hash.delete k if hash[k].empty?
        true
      else
        false
      end

    else
      raise ArgumentError
    end
  end

  def transaction inserts: [], deletes: [], tick: nil
    deletes.each do |tuple|
      delete_once tuple or raise "bug"
    end

    inserts.each do |tuple|
      insert tuple.freeze
    end
  end

  def find_distinct_matches_for templates
    templates.inject([]) do |tuples, template|
      tuples << find_match_for(template, distinct_from: tuples)
    end
  end

  def find_match_for template, distinct_from: []
    ## optimize for templates that correspond to hash lookup
    find do |tuple|
      template === tuple and not distinct_from.any? {|t| t.equal? tuple}
    end
  end
end
