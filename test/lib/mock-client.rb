require 'fiber'

require 'tupelo/client/reader'
require 'tupelo/client/transaction'
require 'tupelo/client/subspace'

require 'mock-queue.rb'

class MockClient
  include Tupelo::Client::Api

  attr_accessor :worker
  attr_accessor :log
  attr_accessor :client_id
  attr_accessor :blobber
  attr_accessor :message_class
  attr_accessor :tuplespace
  attr_accessor :seq
  attr_accessor :arc
  attr_accessor :start_tick

  class IsBlocked < RuntimeError; end
  class IsDone < RuntimeError; end

  def update
    worker.update
  end
  
  def make_queue
    MockQueue.new
  end
  
  def will &block
    (@will_do ||= []) << Fiber.new { instance_eval &block }
    self
  end
  
  def step
    loop do
      fiber = @will_do[0] or raise IsDone, "nothing to do"

      if fiber.alive?
        update
        val = fiber.resume
        update
        return val
      end

      @will_do.shift
    end
  end
  
  def run limit: 100
    loop do
      fiber = @will_do[0] or raise IsDone, "nothing to do"

      count = 0
      while fiber.alive?
        update
        val = fiber.resume
        update
        if fiber.alive? or @will_do.size > 1
          if val == :block
            count += 1
            if count > limit
              raise IsBlocked, "exceeded blocking limit"
            end
          else
            count = 0
            yield val if block_given?
          end
        else
          return val
        end
      end

      @will_do.shift
    end
  end
  
  def run_until_blocked limit: 100, &block
    begin
      run limit: limit, &block
    rescue IsBlocked
      return
    end
    raise IsDone, "run_until_blocked never blocked"
  end
  
  def now limit: 100, &block
    fiber = Fiber.new { instance_eval &block }
    val = nil
    count = 0
    update
    while fiber.alive?
      val = fiber.resume
      if val == :block
        count += 1
        if count > limit
          raise IsBlocked, "cannot now do that -- exceeded blocking limit"
        end
      else
        count = 0
      end
      update
    end
    val
  end
  
  def subscribed_all
    true
  end
end
