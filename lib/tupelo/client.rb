require 'funl/client'

module Tupelo
  class Client < Funl::Client
    require 'tupelo/client/subspace'

    include Api

    require 'tupelo/client/worker'
    require 'tupelo/client/tuplespace'

    attr_reader :worker
    attr_reader :tuplespace

    def initialize(tuplespace: SimpleTuplespace, subscribe: :all, **opts)
      super **opts
      @tuplespace = tuplespace
      @worker = make_worker
      @initial_subscriptions = subscribe || []
    end

    def inspect
      "#<#{self.class} #{client_id} (#{log.progname}) at tick #{worker.global_tick}>"
    end

    def make_worker
      Worker.new self
    end

    def make_queue
      Queue.new ## use lock-free queue based on Atomic
    end

    def start
      super
      worker.start

      case @initial_subscriptions
      when :all
        subscribe_all
      when Array
        subscribe @initial_subscriptions | [Tupelo::Client::TUPELO_SUBSPACE_TAG]
      when String
        @initial_subscriptions = [@initial_subscriptions]
        subscribe @initial_subscriptions | [Tupelo::Client::TUPELO_SUBSPACE_TAG]
      else
        raise ArgumentError,
          "bad subscription specifier: #{@initial_subscriptions}"
      end
    end

    def stop
      worker.stop
    end

    def log *args
      if args.empty?
        super()
      else
        super().unknown *args
      end
    end
  end
end
