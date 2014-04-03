require 'sequel'
require_relative 'event-template'

# A tuple store that is optimized for event data. These tuples are stored in an
# in-memory sqlite database table. Tuples that do not fit this pattern (such
# as metatuples) are stored in an array, as in the default TupleStore class.
class SqliteEventStore
  include Enumerable

  attr_reader :events, :tags, :customs, :alt_customs, :metas
  
  # Template for matching all event tuples.
  attr_reader :event_template

  # Object with #dump and #load methods used to put the custom hash into
  # a sqlite string column.
  attr_reader :blobber

  def initialize spec, client: nil
    @event_template = client.worker.pot_for(spec)
    @blobber = client.blobber
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

      index         [:service, :host, :time]
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
      text          :value_blob
      index         :key
      primary_key   [:event_id, :key]
    end

    @events   = @db[:events]
    @tags     = @db[:tags]
    @customs  = @db[:customs]

    @alt_customs = Hash.new {|h,k| h[k] = {}}
      # Alternate store for any custom that has a non-string key. To be
      # completely correct, we have to support this because the event space
      # requires it.
      #
      # Contains
      #   {event_id => {key => value}}
      # where key (and value, of course) are arbitrary tuple data.
      # We don't have the key index like in the customs table, but that's
      # ok since the key isn't a string.

    @metas = []
  end

  def collect_tags event_id
    tags.
      select(:tag).
      where(event_id: event_id).
      map {|row| row[:tag]}
  end

  def collect_custom event_id
    custom = customs.
      select(:key, :value_blob).
      where(event_id: event_id).
      inject({}) {|h, row|
        h[row[:key].to_sym] = blobber.load(row[:value_blob])
        h
      }

    if alt_customs.key?(event_id)
      custom.merge! alt_customs[event_id]
    end

    custom
  end

  def repopulate tuple
    event_id = tuple.delete :id
    tuple[:tags]    = collect_tags(event_id)
    tuple[:custom]  = collect_custom(event_id)
    tuple
  end

  def each
    events.each {|tuple| yield repopulate(tuple)}
    metas.each {|tuple| yield tuple}
  end

  def insert tuple
    case tuple
    when event_template
      tuple = tuple.dup
      tuple_tags = tuple.delete :tags
      tuple_custom = tuple.delete :custom

      event_id = events.insert(tuple)

      tuple_tags.each do |tag|
        tags << {event_id: event_id, tag: tag}
      end

      tuple_custom.each do |key, value|
        if key.kind_of? Symbol
          blob = Sequel.blob(blobber.dump(value))
          customs << {event_id: event_id, key: key.to_s, value_blob: blob}
        else
          alt_customs[event_id][key] = value
        end
      end

    else
      metas << tuple
    end
  end

  def delete_once tuple
    case tuple
    when event_template
      tuple = tuple.dup
      tuple_tags = tuple.delete :tags
      tuple_custom = tuple.delete :custom

      event_id = events.select(:id).where(tuple).limit(1)
      count = events.where(id: event_id).count

      if count == 0
        false
      elsif count == 1
        if tuple_tags.sort == collect_tags(event_id).sort && ## avoid sort?
           tuple_custom == collect_custom(event_id)
          tags.where(event_id: event_id).delete
          customs.where(event_id: event_id).delete
          alt_customs.delete(event_id)
          events.where(id: event_id).delete
          true
        else
          false
        end
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
      template.find_in self, distinct_from: distinct_from
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
      template.find_all_in self, &bl
    else
      # Fall back to linear search using #each and #===.
      grep template, &bl
    end
  end
end
