require 'tupelo/client'
require 'funl/history-client'

## move to tuplet and make optional (there is a use case: static set of clients)

## should manipulate tuples as strings (at least in msgpack/json cases) instead
## of objects -- use msgpack extension for #hash and #== on packed objects

require 'tupelo/archiver/worker'
require 'tupelo/archiver/tuplestore' ## unless persistent?

module Tupelo
  class Archiver
    include Funl::HistoryClient

    attr_reader :server
    attr_reader :persist_dir
    attr_reader :server_thread

    # How many tuples with count=0 do we permit before cleaning up?
    ZERO_TOLERANCE = 1000

    def initialize server,
        tuplestore: Tupelo::Archiver::TupleStore,
        persist_dir: nil, **opts
        ## when ruby does GC symbols, add this:
        ## symbolize_keys: true
      @server = server
      @persist_dir = persist_dir
      super arc: nil, tuplestore: tuplestore, **opts
    end

    # three kinds of requests:
    #
    # 1. fork a new client, with given Client class, and subselect
    #   using given templates
    #
    # 2. accept tcp/unix socket connection and fork, and then:
    #
    #   a. dump tuples matching given templates OR
    #
    #   b. dump all ops in a given range of the global sequence
    #      matching given templates
    #
    # the fork happens when tuplestore is consistent; we
    # do this by passing cmd to worker thread, with conn
    class ForkRequest
      attr_reader :io
      def initialize io
        @io = io
      end
    end

    def make_worker
      if persist_dir ## ???
        Tupelo::Archiver::Worker.new self, persist_dir: persist_dir
      else
        Tupelo::Archiver::Worker.new self
      end
    end

    def start
      super # start worker thread
      @server_thread = Thread.new do
        run
      end
    end

    def stop
      server_thread.kill if server_thread
      super # stop worker thread
    end

    def run
      loop do
        ## nonblock_accept?
        Thread.new(server.accept) do |conn|
          handle_conn conn
        end
      end
    rescue => ex
      log.error ex
      raise
    end

    def handle_conn conn
      log.debug {"accepted #{conn.inspect}"}
      begin
        worker << ForkRequest.new(conn)
      rescue => ex
        log.error ex
        raise
      end
    end
  end
end
