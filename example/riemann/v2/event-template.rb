# Hard-coded to work with tuples belonging to the "event" subspace 
# and with the SqliteEventStore table defined. This template is designed
# for range queries on service, service and host, or service, host, and time,
# using the composite index.
class EventTemplate
  attr_reader :service, :host, :time, :event_template
  ## todo: support queries by tag or custom key

  # Service, host, and time can be intervals or single values or nil to match
  # any value. The event_template must be the template that matches all tuples
  # in the event subspace. The EventTemplate will match a subset of this
  # subspace.
  def initialize service: nil, host: nil, time: nil, event_template: nil
    @service = service
    @host = host
    @time = time
    @event_template = event_template
  end

  # We only need to define this method if we plan to wait for event tuples
  # locally using this template, i.e. read(template) or take(template).
  # Non-waiting queries (such as read_all) just use #find_in or #find_all_in.
  def === tuple
    @event_template === tuple and
    !@service || @service === tuple[:service] and
    !@host || @host === tuple[:host] and
    !@time || @time === tuple[:time]
  end
  
  # Returns a dataset corresponding to this particular template.
  # Dataset has all columns, including id, because we need id to
  # populate tags and custom key-value data, if any.
  def dataset store
    where_terms = {}
    where_terms[:service] = @service if @service
    where_terms[:host] = @host if @host
    where_terms[:time] = @time if @time
    store.events.where(where_terms)
  end

  # Optimized search function to find a template match that exists already in
  # the table. For operations that wait for a match, #=== is used instead.
  def find_in store, distinct_from: []
    matches = dataset(store).limit(distinct_from.size + 1).all

    distinct_from.each do |tuple|
      if i=matches.index(tuple)
        matches.delete_at i
      end
    end

    store.repopulate(matches.first)
  end

  def find_all_in store
    if block_given?
      dataset(store).each do |tuple|
        yield store.repopulate(tuple)
      end
    else
      dataset(store).map do |tuple|
        store.repopulate(tuple)
      end
    end
  end
end
