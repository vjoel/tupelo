require 'sequel'
require_relative 'poi-template'

# A tuple store that is optimized for POI data. These tuples are stored in an
# in-memory sqlite database table. Tuples that do not fit this pattern (such
# as metatuples) are stored in an array, as in the default TupleStore class.
class PoiStore
  include Enumerable

  attr_reader :table, :metas, :template

  def self.define_poispace client
    client.define_subspace("poi",
      lat:  Numeric,
      lng:  Numeric,
      desc: String
    )
    client.subspace("poi")
      # this waits for ack of write of subspace metatuple, and then
      # it returns the Subspace object, which contains a tag and a template
      # spec, from which we can later construct a correct template in
      # initialize.
  end

  def initialize spec, client: nil
    @template = client.worker.pot_for(spec)
      # calling #pot_for in client means that resulting template
      # will have keys converted as needed (in the case of this client,
      # to symbols).

    clear

    # To be more general, we could inspect the spec to determine which keys to
    # use when creating and querying the table, and in the PoiTemplate class
    # above. This example just assumes the key names are always lat, lng, desc.
  end
  
  def clear
    @db = Sequel.sqlite
    @db.create_table "poi" do
      primary_key   :id # id is not significant to our app
      float         :lat, null: false
      float         :lng, null: false
      text          :desc

      ## spatial_index [:lat, :lng] # by default sqlite doesn't support this
      index         :lat
      index         :lng
    end

    @table = @db[:poi]
    @metas = []
  end

  def each
    table.select(:lat, :lng, :desc).each do |row|
      yield row
    end
    metas.each do |tuple|
      yield tuple
    end
  end

  def insert tuple
    case tuple
    when template
      table << tuple
    else
      metas << tuple
    end
  end

  def delete_once tuple
    case tuple
    when template
      id = table.select(:id).
        where(tuple).
        limit(1)
      count = table.where(id: id).delete

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
    when PoiTemplate
      template.find_in table, distinct_from: distinct_from
    else
      ## if template can match subspace("poi")
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
