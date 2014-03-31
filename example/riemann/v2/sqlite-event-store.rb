require 'sequel'
require_relative 'event-template'

# A tuple store that is optimized for event data. These tuples are stored in an
# in-memory sqlite database table. Tuples that do not fit this pattern (such
# as metatuples) are stored in an array, as in the default TupleStore class.
class SqliteEventStore
  include Enumerable

  attr_reader :events, :metas
  
  # Template for matching all event tuples.
  attr_reader :event_template

  def initialize spec, client: nil
    @event_template = client.worker.pot_for(spec)
      # calling #pot_for in client means that resulting template
      # will have keys converted as needed (in the case of this client,
      # to symbols).

    clear

    # To be more general, we could inspect the spec to determine which keys to
    # use when creating and querying the table
  end
  
  def clear
    @db = Sequel.sqlite
    @db.create_table :events do
      primary_key   :id # id is not significant to our app
      text          :host, null: false
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
    events.
      select(:host, :service, :state, :time, :description, :metric, :ttl).
      each do |tuple|

      ## extra queries for tags and custom 
      tuple[:tags] = []
      tuple[:custom] = nil

      yield tuple
    end

    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    case tuple
    when event_template
      tuple = tuple.dup
      tags = tuple.delete :tags
      custom = tuple.delete :custom

      ## insert tags and custom

      events << tuple

    else
      metas << tuple
    end
  end

  def delete_once tuple
    case tuple
    when event_template
      tuple = tuple.dup
      tags = tuple.delete :tags
      custom = tuple.delete :custom

      id = events.select(:id).where(tuple).limit(1)
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

  def find_all_matches_for template, &bl
    case template
    when EventTemplate
      template.find_all_in events, &bl
    else
      # Fall back to linear search using #each and #===.
      grep template, &bl
    end
  end
end
