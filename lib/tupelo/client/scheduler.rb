require 'atdo'

module Tupelo
  class Client
    class Scheduler < AtDo
      DEFAULT_STORAGE =
        begin
          require 'rbtree'
          MultiRBTree
        rescue LoadError
          Array
        end

      # Instead of calling this method, call Client#make_scheduler.
      def initialize client, **opts
        @client = client
        super(**opts)
      end

      # Accepts numeric +time+ or Time instance. Logs errors that occur
      # in +action+. Otherwise, same as AtDo#at from the atdo gem.
      def at time, &action
        time = Time.at(time) if time.kind_of? Numeric
        super time do
          begin
            action.call
          rescue => ex
            @client.log.error "error in action scheduled for #{time}:" +
              " #{ex.class}: #{ex}\n  #{ex.backtrace.join("\n  ")}"
          end
        end
      end
    end

    # Returns a scheduler, which has a method that you can call to schedule
    # an action at a time:
    #
    #   s = make_scheduler # or client.make_scheduler
    #   s.at t do ... end
    #
    # where t can be either a Time or Numeric seconds.
    #
    # The scheduler runs in its own thread. It uses a red-black tree to store
    # the actions, if the rbtree gem is installed and you do not specify
    # 'storage: Array'. Otherwise it uses a sorted Array, which is fine for
    # small schedules.
    #
    # Scheduler is used internally by Worker to manage transaction timeouts,
    # but client code may create its own scheduler -- see example/lease.rb.
    #
    def make_scheduler **opts
      opts[:storage] ||= Scheduler::DEFAULT_STORAGE
      Scheduler.new self, **opts
    end
  end
end
