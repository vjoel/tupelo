class MockQueue
  class QueueEmptyError < StandardError; end
  
  attr_reader :entries
  attr_reader :yield_on_push
  attr_reader :yield_on_pop
  
  def initialize yield_on_push: false, yield_on_pop: false
    @entries = []
    @yield_on_push = yield_on_push
    @yield_on_pop = yield_on_pop
  end
  
  def empty?
    entries.empty?
  end
  
  def push val
    @entries << val
    if yield_on_push
      Fiber.yield([:push, val]) rescue FiberError
    end
  end
  alias << push
  
  def pop
    begin
      while @entries.empty?
        Fiber.yield :block
      end
    rescue FiberError
      raise QueueEmptyError, "queue empty"
    end
    
    val = @entries.shift
    if yield_on_pop
      Fiber.yield([:pop, val]) rescue FiberError
    end
    val
  end
end

