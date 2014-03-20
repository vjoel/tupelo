# Hard-coded to work with tuples belonging to the "poi" subspace
# and with the PoiStore table.
class PoiTemplate
  attr_reader :lat, :lng
  
  # Template for matching all POI tuples.
  attr_reader :poi_template

  # lat and lng can be intervals or single values or nil to match any value
  def initialize lat: nil, lng: nil, poi_template: nil
    @lat = lat
    @lng = lng
    @poi_template = poi_template
  end

  # we only need to define this method if we plan to wait for poi tuples
  # locally using this template, i.e. read(template) or take(template)
  def === tuple
    @poi_template === tuple and
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

    # Note: everything in this method up to and including where(...) can
    # be called once and reused as a sequel dataset.

    distinct_from.each do |tuple|
      if i=matches.index(tuple)
        matches.delete_at i
      end
    end

    matches.first
  end

  def find_all_in table, &bl
    where_terms = {}
    where_terms[:lat] = @lat if @lat
    where_terms[:lng] = @lng if @lng

    matches = table.
      select(:lat, :lng, :desc).
      where(where_terms)

    if bl
      matches.each(&bl)
    else
      matches.all
    end
  end
end
