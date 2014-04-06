# A toy implementation of Riemann (http://riemann.io).
#
# Version 2 stores the event subspace using different data
# structures in different clients, depending on needs:
#
#   * generic consumers need to index by service, host, and time,
#     by tags, and by custom keys, so they use in-memory sqlite with
#     normalized tables.
#
#   * the expiration manager needs to sort by expiration time, so
#     it uses an rbtree (an in-memory Red-Black binary tree),
#     for a good balance of insert and lookup performance.
#
#   * the critical event alerter doesn't need to sort or search at all,
#     it just needs efficient insert and delete, so it uses a store
#     based on a simple hash table.
#
# Run with --http to expose a web API and run a test web client.
#
# You will need to `gem install rbtree sqlite3 sequel`.
# For the --http option, you'll also need to `gem install http json sinatra`.

USE_HTTP = ARGV.delete("--http")

if USE_HTTP
  require_relative 'http-mode'
  start_web_client
  at_exit {Process.waitall}
end

require 'tupelo/app'
require_relative '../event-subspace'
require_relative '../producer'
require_relative 'expirer'
require_relative 'hash-store'
require_relative 'sqlite-event-store'

N_PRODUCERS = 3
N_CONSUMERS = 1

Tupelo.application do
  local do
    define_event_subspace
    EVENT_SPACE = subspace("event")
  end

  if USE_HTTP
    # Web API using sinata to access the index of events.
    child subscribe: "event" do |client|
      log.progname = "web server"
      run_web_server(client)
    end
  end

  N_PRODUCERS.times do |i|
    child subscribe: [] do # N.b., no subscriptions
      log.progname = "producer #{i}"
      run_producer i
    end
  end

  N_CONSUMERS.times do |i|
    # stores events indexed by host, service
    child tuplestore: [SqliteEventStore, EVENT_SPACE.spec],
          subscribe: "event",
          symbolize_keys: true, # for ease of use with sequel DB interface
          passive: true do
      log.progname = "consumer #{i}"
      read subspace("event") do |event|
        log.info event # add analytics here
      end
    end
  end
  
  # critical event alerter
  child tuplestore: HashStore, subscribe: "event", passive: true do
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
  child tuplestore: OrderedEventStore, subscribe: "event", passive: true do
    log.progname = "expirer"
    run_expirer_v2
  end
end
