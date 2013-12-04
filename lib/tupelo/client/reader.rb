require 'tupelo/client/common'

class Tupelo::Client
  # Include into class that defines #worker and #log.
  module Api
    # If no block given, return one matching tuple, blocking if necessary.
    # If block given, yield all matching tuples that are found
    # locally and then yield each new match written to the space.
    # Guaranteed not to miss tuples, even if they arrive and are immediately
    # taken.
    # The template defaults to Object, which matches any tuple.
    def read_wait template = Object
      waiter = Waiter.new(worker.make_template(template), self, !block_given?)
      worker << waiter
      if block_given?
        loop do
          yield waiter.wait
        end
      else
        result = waiter.wait
        waiter = nil
        result
      end
    ensure
      worker << Unwaiter.new(waiter) if waiter
    end
    alias read read_wait

    def read_nowait template
      matcher = Matcher.new(worker.make_template(template), self)
      worker << matcher
      matcher.wait
    end

    # By default, reads *everything*.
    def read_all template = Object
      matcher = Matcher.new(worker.make_template(template), self, :all => true)
      worker << matcher
      a = []
      while tuple = matcher.wait ## inefficient?
        yield tuple if block_given?
        a << tuple
      end
      a
    end

    def notifier
      NotifyWaiter.new(self).tap {|n| n.toggle}
    end
  end

  class WaiterBase
    attr_reader :template
    attr_reader :queue
    attr_reader :once

    def initialize template, client, once = true
      @template = template
      @queue = client.make_queue
      @client = client
      @once = once
    end

    def gloms tuple
      if template === tuple
        peek tuple
      else
        false
      end
    end
    
    def peek tuple
      queue << tuple
      once
    end

    def wait
      @client.log.debug {"waiting for #{inspect}"}
      r = queue.pop
      @client.log.debug {"finished waiting for #{inspect}"}
      r
    end

    def inspect
      "<#{self.class}: #{template.inspect}>"
    end
  end
  
  class Waiter < WaiterBase
  end
  
  class Matcher < WaiterBase
    attr_reader :all # this is only cosmetic -- see #inspect

    def initialize template, client, all: false
      super template, client
      @all = all
    end

    def fails
      queue << nil
    end

    def inspect
      e = all ? "all " : ""
      t = template.inspect
      "<#{self.class}: #{e}#{t}>"
    end
  end

  # Instrumentation.
  class NotifyWaiter
    attr_reader :queue

    def initialize client
      @client = client
      @queue = client.make_queue
    end

    def << event
      queue << event
    end

    def wait
      queue.pop
    end

    def toggle
      @client.worker << self
    end

    def inspect
      to_s
    end
  end
end
