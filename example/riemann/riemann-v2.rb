# A toy implementation of Riemann (http://riemann.io).
#
# Version 2 stores the event subspace using different data
# structures in different clients, depending on needs:
#
#   * generic consumers need to index by host and service
#
#   * the expiration manager need to sort by expiration time
#
#   * the critical event alerter doesn't need to sort at all.

abort "work in progress"

require 'tupelo/app'
require_relative 'event-subspace'
require_relative 'producer'
require_relative 'expirer-v2'

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
      run_producer i ### V2: manual tagging
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
  
  # critical event alerter
  child subscribe: "event", passive: true do ### tuplespace: bag?
    log.progname = "alerter"
    read Tupelo::Client::CRITICAL_EVENT do |event|
      log.error event
    end
  end

  if argv.include?("--debug-expiration")
    # expired event debugger
    child subscribe: "event", passive: true do
      log.progname = "expiration debugger"
      read Tupelo::Client::EXPIRED_EVENT do |event|
        log event
      end
    end
  end

  # expirer: stores current events and looks for events that can be expired.
  child subscribe: "event", passive: true do
    log.progname = "expirer"
    run_expirer_v2
    ### use rbtree
  end
  
  ### Add sinatra app.
end
