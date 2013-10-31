require 'funl/client'

module Tupelo
  class Client < Funl::Client
    require 'tupelo/client/worker'
    require 'tupelo/client/tuplespace'

    include Api

    attr_reader :worker
    attr_reader :tuplespace

    TUPELO_SUBSPACE_TAG = "tupelo subspace"

    def initialize(tuplespace: SimpleTuplespace, subscribe: :all, **opts)
      super **opts
      @tuplespace = tuplespace
      @worker = make_worker
      @initial_subscriptions = subscribe
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
        subscribe @initial_subscriptions
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
