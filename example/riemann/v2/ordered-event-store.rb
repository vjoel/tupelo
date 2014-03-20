require 'rbtree'

# Hard-coded to work with tuples belonging to the "event" subspace defined in
# event-subspace.rb and with the OrderedEventStore data structure defined below.
class OrderedEventTemplate
  attr_reader :expiration

  def self.before event
    new(event: event)
  end

  def initialize event: event
    time = event["time"] || event[:time]
    ttl = event["ttl"] || event[:ttl]
       # We check symbol keys in case of manually specified event, rather than
       # tuples that passed thru tupelo.
    @expiration = time + ttl
  end

  def === other
    begin
      other["time"] + other["ttl"] < @expiration
    rescue
      false
    end
    # Should check that subspace("event") === other, but in this example
    # we don't need to, we just make sure it's got time and ttl keys.
    # Anyway, the #=== method is not used, since in this case
    # we just lookup using RBTree#first. See the special case for
    # OrderedEventTemplate in OrderedEventStore#find_match_for.
    # This implementation is just for completeness.
  end
end

# A tuple store (in-memory) that is optimized for events and for searching them
# in expiration order. This is very much a special case and not reusable for
# other spaces/stores without modification.
#
# This store also manages meta tuples, which it keeps in an array,
# just like the default TupleStore class does. Actually, any tuple for which
# `tuple["time"] + tuple["ttl"]` raises an exception will go in the metas,
# but in this example the process only subscribes to events and metas.
#
class OrderedEventStore
  include Enumerable

  attr_reader :tree, :metas

  def initialize
    clear
  end

  def clear
    @tree = RBTree.new{|t,k| t[k] = []}
    @metas = []
      # We are automatically subscribed to tupelo metadata (subspace defs), so
      # we need to keep them somewhere.
  end

  def each
    tree.each do |k, events|
      events.each do |event|
        yield event
      end
    end
    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    k = tuple["time"] + tuple["ttl"]
  rescue
    metas << tuple
  else
    tree[k] << tuple
  end

  def delete_once tuple
    k = tuple["time"] + tuple["ttl"]
  rescue
    if i=metas.index(tuple)
      metas.delete_at i
    end
  else
    if tree.key?(k) and tree[k].include? tuple
      tree[k].delete tuple
      tree.delete k if tree[k].empty?
      true
    else
      false
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
    when OrderedEventTemplate
      k, firsts = tree.first
      k && k < template.expiration &&
        firsts.find {|tuple| distinct_from.all? {|t| !t.equal? tuple}}
      # The `find` clause isn't really needed, since OrderedEventTemplate is
      # only used for reads, not takes, and anyway we never take multiple
      # tuples in a transaction on the event space so the array would be empty.
      # But let's be correct... Note the use of #equal?.
    else
      # Fall back to linear search, same as default tuplestore.
      find do |tuple|
        template === tuple and not distinct_from.any? {|t| t.equal? tuple}
      end
    end
  end
end
