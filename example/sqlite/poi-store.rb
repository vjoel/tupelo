require 'sequel'

# Hard-coded to work with tuples belonging to the "poi" subspace 
# and with the PoiStore table defined below.
class PoiTemplate
  attr_reader :lat, :lng, :poispace

  # lat and lng can be intervals or single values or nil to match any value
  def initialize lat: nil, lng: nil, poispace: nil
    @lat = lat
    @lng = lng
    @poispace = poispace
  end

  # we only need to define this method if we plan to wait for poi tuples
  # locally using this template, i.e. read(template) or take(template)
  def === tuple
    @poispace === tuple and
    !@lat || @lat === tuple[:lat] and
    !@lng || @lng === tuple[:lng]
  end

  def find_in table, distinct_from: []
    where_terms = {}
    where_terms[:lat] = @lat if @lat
    where_terms[:lng] = @lng if @lng

    matches = table.
      select(:lat, :lng, :desc).
      where(where_terms).
      limit(distinct_from.size + 1).all

    distinct_from.each do |tuple|
      if i=matches.index(tuple)
        matches.delete_at i
      end
    end

    matches.first
  end
end

# A tuple store that is optimized for POI data. These tuples are stored in an
# in-memory sqlite database table. Tuples that do not fit this pattern (such
# as metatuples) are stored in an array, as in the default Tuplespace class.
class PoiStore
  include Enumerable

  attr_reader :table, :metas, :poispace

  def self.define_poispace client
    client.define_subspace("poi",
      lat:  Numeric,
      lng:  Numeric,
      desc: String
    )
    client.subspace("poi") ## is this awkward?
  end

  # poispace should be client.subspace("poi"), but really we only need
  # poispace.pot
  def initialize poispace
    @poispace = poispace
    clear
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
    when poispace
      table << tuple
    else
      metas << tuple
    end
  end

  def delete_once tuple
    case tuple
    when poispace
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
