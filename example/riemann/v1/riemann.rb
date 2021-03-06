# A toy implementation of Riemann (http://riemann.io).
#
# Version 1 uses the default tuplestore for all subspaces, which is inefficient
# for searching.

require 'tupelo/app'
require_relative '../event-subspace'
require_relative '../producer'
require_relative 'expirer'

N_PRODUCERS = 3
N_CONSUMERS = 2

Tupelo.application do
  local do
    define_event_subspace
  end

  N_PRODUCERS.times do |i|
    child subscribe: [] do # N.b., no subscriptions
      log.progname = "producer #{i}"
      run_producer i
    end
  end

  N_CONSUMERS.times do |i|
    # stores events
    child subscribe: "event", passive: true do
      log.progname = "consumer #{i}"
      read subspace("event") do |event|
        log event # add analytics here
      end
    end
  end
  
  # critical event alerter
  child subscribe: "event", passive: true do
    log.progname = "alerter"
    read Tupelo::Client::CRITICAL_EVENT do |event|
      log.error event
    end
  end

  if argv.include?("--debug-expiration")
    # expired event debugger
    require_relative '../expiration-dbg'
    child subscribe: "event", passive: true do
      log.progname = "expiration debugger"
      run_expiration_debugger
    end
  end

  # expirer: stores current events and looks for events that can be expired.
  child subscribe: "event", passive: true do
    log.progname = "expirer"
    run_expirer_v1
  end
end
