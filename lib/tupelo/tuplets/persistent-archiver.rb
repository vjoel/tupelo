require 'tupelo/client'
require 'funl/history-client'

class Tupelo::PersistentArchiver < Tupelo::Client; end

require 'tupelo/tuplets/persistent-archiver/worker'
require 'tupelo/tuplets/persistent-archiver/tuplespace'

module Tupelo
  class PersistentArchiver
    include Funl::HistoryClient

    attr_reader :server
    attr_reader :server_thread

    # How many tuples with count=0 do we permit before cleaning up?
    ZERO_TOLERANCE = 1000

    def initialize server, **opts
      super arc: nil, tuplespace: Tupelo::PersistentArchiver::Tuplespace, **opts
      @server = server
    end

    # three kinds of requests:
    #
    # 1. fork a new client, with given Client class, and subselect
    #   using given templates
    #
    # 2. accept tcp/unix socket connection and fork, and then:
    #
    #   a. dump subspace matching given templates OR
    #
    #   b. dump all ops in a given range of the global sequence
    #      matching given templates
    #
    # the fork happens when tuplespace is consistent; we
    # do this by passing cmd to worker thread, with conn
    class ForkRequest
      attr_reader :io
      def initialize io
        @io = io
      end
    end

    def make_worker
      Tupelo::PersistentArchiver::Worker.new self
    end

    def start
      ## load from file?
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

        ## periodically send worker request to dump space to file?
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
