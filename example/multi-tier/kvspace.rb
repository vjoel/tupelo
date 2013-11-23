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
# This store also manages meta tuples, which it keeps in an array, just like
# the default Tuplespace class does.
class KVSpace
  include Enumerable

  attr_reader :tag, :hash, :metas

  def initialize tag
    @tag = tag
    clear
  end

  def clear
    @hash = Hash.new {|h,k| h[k] = []}
      # It's up to the application to enforce that these arrays have size <=1.
    @metas = []
      # We are automatically subscribed to tupelo metadata (subspace defs), so
      # we need to keep them somewhere.
  end

  def each
    hash.each do |k, vs|
      vs.each do |v|
        yield tag, k, v
      end
    end
    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    if tuple.kind_of? Array
        # and tuple.size == 3 and tuple[0] == tag and tuple[1].kind_of? String
        # This is redundant, because of subscribe.
      t, k, v = tuple
      hash[k] << v

    else
      metas << tuple
    end
  end

  def delete_once tuple
    if tuple.kind_of? Array
        # and tuple.size == 3 and tuple[0] == tag and tuple[1].kind_of? String
        # This is redundant, because of subscribe.
      t, k, v = tuple
      if hash.key?(k) and hash[k].include? v
        hash[k].delete v
        hash.delete k if hash[k].empty?
        true
      else
        false
      end

    else
      if i=metas.index(tuple)
        delete_at i
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
    # try to optimize if template can be satisfied by hash lookup
    if template.kind_of? RubyObjectTemplate
      spec = template.spec
      if spec.kind_of? Array
        key = spec[1]
        if key.kind_of? String and spec[2] == nil
          if hash.key? key
            value = hash[key].last # most recently written
            return [tag, key, value]
          else
            return nil
          end
        end
      end
    end
    
    # fall back to linear search
    find do |tuple|
      template === tuple and not distinct_from.any? {|t| t.equal? tuple}
    end
  end
end
