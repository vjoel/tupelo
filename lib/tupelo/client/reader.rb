require 'tupelo/client/common'

class Tupelo::Client
  # Include into class that defines #worker and #log.
  module Api
    def not_meta
      k = tupelo_meta_key
      @not_meta ||= proc {|t| not defined? t.key? or not t.key? k}
    end

    # If no block given, return one matching tuple, blocking if necessary.
    # If block given, yield each matching tuple that is found
    # locally and then yield each new match as it is written to the store.
    # Guaranteed not to miss tuples, even if they arrive and are immediately
    # taken. (Note that simply doing read(template) in a loop would not
    # have this guarantee.)
    # The template defaults to not_meta, which matches any tuple except metas.
    # The first phase of this method, reading existing tuples, is essentially
    # the same as read_all, and subject to the same warnings.
    def read_wait template = not_meta
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

    # The template defaults to not_meta, which matches any tuple except metas.
    def read_nowait template = not_meta
      matcher = Matcher.new(worker.make_template(template), self)
      worker << matcher
      matcher.wait
    end

    # Returns all matching tuples currently in the store. Does not wait for more
    # tuples to arrive. The template defaults to not_meta, which matches any
    # tuple except metas. To read all matches of more than one template, use
    # the #or method from util/boolean.rb.
    # Matches are guaranteed to exist at the same tick (even if they no longer
    # exist after that tick). To take a snapshot like this, the worker is
    # blocked from all other activity for some time, so be careful about
    # using read_all when large numbers of tuples match. If a block is given,
    # it runs after the worker has unblocked.
    def read_all template = not_meta
      matcher = Matcher.new(worker.make_template(template), self, :all => true)
      worker << matcher
      a = []
      while tuple = matcher.wait ## inefficient to wait one at a time?
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
