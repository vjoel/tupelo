# Hard-coded to work with tuples belonging to the "event" subspace 
# and with the SqliteEventStore table defined. This template is designed
# for range queries on host, or on host and service, using the composite index.
class EventTemplate
  attr_reader :host, :service, :event_template

  # host and service can be intervals or single values or nil to match any value
  def initialize host: nil, service: nil, event_template: nil
    @host = host
    @service = service
    @event_template = event_template
  end

  # we only need to define this method if we plan to wait for event tuples
  # locally using this template, i.e. read(template) or take(template).
  # Non-waiting queries (such as read_all) just use #find_in or #find_all_in.
  def === tuple
    @event_template === tuple and
    !@host || @host === tuple[:host] and
    !@service || @service === tuple[:service]
  end
  
  def dataset events
    where_terms = {}
    where_terms[:host] = @host if @host
    where_terms[:service] = @service if @service
    events.
      select(:host, :service, :state, :time, :description, :metric, :ttl).
      where(where_terms)
  end

  # Optimized search function to find a template match that exists already in
  # the table. For operations that wait for a match, #=== is used instead.
  def find_in events, distinct_from: []
    matches = dataset(events).limit(distinct_from.size + 1).all

    distinct_from.each do |tuple|
      if i=matches.index(tuple)
        matches.delete_at i
      end
    end

    tuple = matches.first

    ## get the tags and custom
    tuple[:tags] = []
    tuple[:custom] = nil

    tuple
  end

  def find_all_in events
    if block_given
      dataset(events).each do |tuple|
        ## get the tags and custom
        tuple[:tags] = []
        tuple[:custom] = nil
        yield tuple
      end
    else
      dataset(events).map do |tuple|
        ## get the tags and custom
        tuple[:tags] = []
        tuple[:custom] = nil
        tuple
      end
    end
  end
end
