# A toy implementation of Riemann (http://riemann.io).
#
# Version 1 uses the default tuplespace for all subspaces, which is inefficient
# for searching.

require 'tupelo/app'
require_relative 'event-subspace'

N_PRODUCERS = 3
N_CONSUMERS = 2

Tupelo.application do

  local do
    use_subspaces!
    define_event_subspace
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
        ttl:          0,
        custom:       nil
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
    child subscribe: "event", passive: true do
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
  child subscribe: "event", passive: true do
    log.progname = "alerter"
    read critical_event do |event|
      log.error event
    end
  end

  # expirer: stores current events in expiration order
  child subscribe: "event", passive: true do
    log.progname = "expirer"
  end
end
