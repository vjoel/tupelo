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
#
# Run with --http to expose a web API and run a test web client.

USE_HTTP = ARGV.delete("--http")

if USE_HTTP
  # Run a web client
  fork do # No tupelo in this process.
    sleep 1.0 # let some data arrive
    require 'http'

    url = 'http://localhost:4567'

    print "trying server at #{url}"
    begin
      print "."
      HTTP.get url
    rescue Errno::ECONNREFUSED
      sleep 0.2
      retry
    end

    puts
    puts HTTP.get "#{url}/read"
  end
end

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
        ###log event ### need filtering, actions, etc.
      end
    end
  end
  
  # critical event alerter
  child subscribe: "event", passive: true do ### tuplespace: hash?
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
        event_exp = event["time"] + event["ttl"]
        delta = Time.now.to_f - event_exp
        if delta > 0.1
          log.warn "expired late by %6.4f seconds: #{event}" % delta
        elsif delta < 0
          log.warn "expired too soon: #{event}"
        else
          log "expired on time: #{event}"
        end
      end
    end
  end

  # expirer: stores current events and looks for events that can be expired.
  child tuplespace: OrderedEventStore, subscribe: "event", passive: true do
    log.progname = "expirer"
    run_expirer_v2
  end

  if USE_HTTP
    # Web API using sinata to access the index of events.
    child subscribe: "event", passive: true do |client|
      require 'sinatra/base'

      Class.new(Sinatra::Base).class_eval do
        get '/read' do
          host = params["host"] # nil is ok -- matches all hosts
          resp = client.read(
            host:         host,
            service:      nil,
            state:        nil,
            time:         nil,
            description:  nil,
            tags:         nil,
            metric:       nil,
            ttl:          nil,
            custom:       nil
          )
          resp.to_json + "\n"
        end
        ## need way to query by existence of tag

        run!
      end
    end
  end
end

Process.waitall if USE_HTTP

