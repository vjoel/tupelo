require 'funl/client'

module Tupelo
  class Client < Funl::Client
    require 'tupelo/client/worker'
    require 'tupelo/client/tuplespace'

    include Api

    attr_reader :worker
    attr_reader :tuplespace

    def initialize(tuplespace: SimpleTuplespace, **opts)
      super **opts
      @tuplespace = tuplespace
      @worker = make_worker
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
      subscribe_all ## for now, but eventually should start without subs
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
