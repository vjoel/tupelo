require 'fiber'

require 'tupelo/client/reader'
require 'tupelo/client/transaction'

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

  def update
    worker.update
  end
  
  def make_queue
    MockQueue.new
  end
  
  def will &block
    (@will_do ||= []) << Fiber.new { instance_eval &block }
  end
  
  def step
    loop do
      fiber = @will_do[0] or raise "nothing to do"

      while fiber.alive?
        update
        val = fiber.resume
        update
        return val
      end

      @will_do.shift
    end
  end
  
  def run
    loop do
      fiber = @will_do[0] or raise "nothing to do"

      while fiber.alive?
        update
        val = fiber.resume
        update
        if fiber.alive? or @will_do.size > 1
          yield val if block_given?
        else
          return val
        end
      end

      @will_do.shift
    end
  end
  
  def immediately &block
    fiber = Fiber.new { instance_eval &block }
    val = nil
    while fiber.alive?
      update
      val = fiber.resume
      if val == :block
        raise "cannot immediately do that -- blocked"
      end
      update
    end
    val
  end
end
