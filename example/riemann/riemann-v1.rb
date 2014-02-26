# A toy implementation of Riemann (http://riemann.io)
#
# Also, this is an example of storing a subspace using different data
# structures in different clients, depending on needs: some clients (generic
# consumers) need to index by host and service, and others (expiration manager)
# need to sort by expiration time,  and others (critical event alerter) don't
# need to sort at all.

require 'tupelo/app'

N_PRODUCERS = 3
N_CONSUMERS = 2

Tupelo.application do

  local do
    use_subspaces!

    define_subspace("event", {
    # field         type        description
    #                           (from http://riemann.io/concepts.html)

      host:         String,   # A hostname, e.g. "api1", "foo.com"

      service:      String,   # e.g. "API port 8000 reqs/sec"

      state:        String,   # Any string less than 255 bytes, e.g. "ok",
                              # "warning", "critical"

      time:         Numeric,  # The time of the event, in unix epoch seconds

      description:  String,   # Freeform text

      tags:         Array,    # Freeform list of strings,
                              # e.g. ["rate", "fooproduct", "transient"]

      metric:       Numeric,  # A number associated with this event,
                              # e.g. the number of reqs/sec.

      ttl:          Numeric   # A floating-point time, in seconds, that this
                              # event is considered valid for. Expired states
                              # may be removed from the index.
    })
  end

  N_PRODUCERS.times do |i|
    child subscribe: [] do # N.b., no subscriptions
      log.progname = "producer #{i}"
      event = {
        host:         `hostname`.chomp,
        service:      "service #{client_id}", # placeholder
        state:        "",
        time:         0,
        description:  "",
        tags:         [],
        metric:       0,
        ttl:          0
      }.freeze

      e_ok = event.merge(
        state:    "ok",
        time:     Time.now.to_f,
        ttl:      1.0
      )

      if e_ok[:ttl] == 0.0
        pulse e_ok # no need to bother with expiration
      else
        write e_ok
      end
    end
  end

  N_CONSUMERS.times do |i|
    # stores events indexed by host, service
    child subscribe: "event", passive: true do ### tuplespace: sqlite
      log.progname = "consumer #{i}"
      read subspace("event") do |event|
        log event ### need filtering, actions, etc.
      end
    end
  end
  
  # This could be a subspace of the event subspace.
  critical_event = {
    host:        nil,
    service:     nil,
    state:       /critical|fatal/i,
    time:        nil,
    description: nil,
    tags:        nil,
    metric:      nil,
    ttl:         nil
  }
  
  # critical event alerter
  child subscribe: "event", passive: true do ### tuplespace: bag?
    log.progname = "alerter"
    read critical_event do |event|
      log.error event
    end
  end

  # expirer: stores current events in expiration order
  child subscribe: "event", passive: true do
    log.progname = "expirer"
    ### use rbtree
  end
end
