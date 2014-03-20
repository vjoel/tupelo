require 'sequel'

# Hard-coded to work with tuples belonging to the "event" subspace 
# and with the SqliteEventStore table defined below. This template is designed
# for range queries on host, or on host and service, using the composite index.
class EventTemplate
  attr_reader :host, :service, :space

  # host and service can be intervals or single values or nil to match any value
  def initialize host: nil, service: nil, space: nil
    @host = host
    @service = service
    @space = space
  end

  # we only need to define this method if we plan to wait for event tuples
  # locally using this template, i.e. read(template) or take(template).
  # Non-waiting queries (such as read_all) just use #find_in.
  def === tuple
    @space === tuple and
    !@host || @host === tuple["host"] and
    !@service || @service === tuple["service"]
  end

  # Optimized search function to find a template match that exists already in
  # the table. For operations that wait for a match, #=== is used instead.
  def find_in events, distinct_from: []
    where_terms = {}
    where_terms[:host] = @host if @host
    where_terms[:service] = @service if @service

    matches = events.
      ### select all but id
      where(where_terms).
      limit(distinct_from.size + 1).all

    distinct_from.each do |tuple|
      if i=matches.index(tuple)
        matches.delete_at i
      end
    end

    matches.first ## get the tags and customs
    ### convert sym to string?
  end
end

# A tuple store that is optimized for event data. These tuples are stored in an
# in-memory sqlite database table. Tuples that do not fit this pattern (such
# as metatuples) are stored in an array, as in the default TupleStore class.
class SqliteEventStore
  include Enumerable

  attr_reader :events, :metas, :space

  # space should be client.subspace("event"), but really we only need
  # `space.pot` the portable object template for deciding membership.
  def initialize space
    @space = space
    clear
  end
  
  def clear
    @db = Sequel.sqlite
    @db.create_table :events do
      primary_key   :id # id is not significant to our app
      text          :host, null: false ## need this ?
      text          :service, null: false
      text          :state
      number        :time
      text          :description
      number        :metric
      number        :ttl

      index         [:host, :service]
    end

    @db.create_table :tags do
      foreign_key   :event_id, :events
      text          :tag
      index         :tag
      primary_key   [:event_id, :tag]
    end

    @db.create_table :customs do
      foreign_key   :event_id, :events
      text          :key
      text          :value
      index         :key
      primary_key   [:event_id, :key]
    end

    @events = @db[:events]
    @metas = []
  end

  def each
    events.each do |row|
      ## extra queries for tags and custom 
      # yuck, gotta convert symbol keys to string keys:
      tuple = row.inject({}) {|h, (k,v)| h[k.to_s] = v; h}
      yield tuple
    end
    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    case tuple
    when space
      events << tuple ## minus tags and customs
    else
      metas << tuple
    end
  end

  def delete_once tuple
    case tuple
    when space
      # yuck, gotta convert string keys to symbol keys:
      row = tuple.inject({}) {|h, (k,v)| h[k.to_sym] = v; h}
      id = events.select(:id).where(row).limit(1)
      count = events.where(id: id).delete

      if count == 0
        false
      elsif count == 1
        true
      else
        raise "internal error: primary key, id, was not unique"
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
    when EventTemplate
      template.find_in events, distinct_from: distinct_from
    else
      ## if template can match subspace
      # Fall back to linear search, same as default tuplestore.
      find do |tuple|
        template === tuple and not distinct_from.any? {|t| t.equal? tuple}
      end
      ## else
      ##   metas.find do |tuple|
      ##     template === tuple and not distinct_from.any? {|t| t.equal? tuple}
      ##   end
      ## end
    end
  end
end
