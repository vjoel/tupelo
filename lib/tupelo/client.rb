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
        subscribe @initial_subscriptions | [Tupelo::Client::TUPELO_SUBSPACE_TAG]
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
    
    ## do these belong in API module?
    def define_subspace metatuple
      defaults = {__tupelo__: "subspace", addr: nil}
      write_wait defaults.merge!(metatuple)
    end
    
    # call this just once at start of first client (it's optional to
    # preserve behavior of non-subspace-aware code)
    def use_subspaces!
      define_subspace(
        tag:          TUPELO_SUBSPACE_TAG,
        template:     {
          __tupelo__: {value: "subspace"},
          tag:        nil,
          addr:       nil,
          template:   nil
        }
      )
    end

    def subspace tag
      tag = tag.to_s
      worker.subspaces.find {|sp| sp.tag == tag}
    end
  end
end
