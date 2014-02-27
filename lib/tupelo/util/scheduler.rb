require 'tupelo/client/atdo'

module Tupelo
  class Client
    SCHEDULER_STORAGE =
      begin
        require 'rbtree'
        MultiRBTree
      rescue LoadError
        Array
      end

    def make_scheduler **opts
      if opts.key? :storage
        AtDo.new self, **opts
      else
        opts.update storage: SCHEDULER_STORAGE
        AtDo.new self, **opts
      end
    end
  end
end
