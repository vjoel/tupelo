require 'minitest/autorun'

require 'mock-queue.rb'

class TestMockQueueWithPushPopYields < Minitest::Test
  def setup
    @q = MockQueue.new yield_on_push: true, yield_on_pop: true
  end
  
  def test_push
    f = Fiber.new do |val|
      loop do
        val = @q.push val
      end
    end
    
    a = []
    assert_equal a, @q.entries
    
    3.times do |i|
      op, val = f.resume i
      assert_equal :push, op
      assert_equal i, val
      a << i
      assert_equal a, @q.entries
    end
  end
  
  def test_pop
    a = []
    f = Fiber.new do
      loop do
        a << @q.pop
      end
    end
    
    3.times do
      op = f.resume
      assert_equal :block, op
      assert_equal [], a
    end
    
    @q.entries.concat (0...10).to_a
    
    10.times do |i|
      op, val = f.resume
      assert_equal :pop, op
      assert_equal i, val
    end
    
    op = f.resume
    assert_equal :block, op
    assert_equal a, (0...10).to_a
  end
end

class TestMockQueueSimpler < Minitest::Test
  def setup
    @q = MockQueue.new
  end
  
  def test_push
    a = []
    assert_equal a, @q.entries
    
    3.times do |i|
      @q.push i
      a << i
      assert_equal a, @q.entries
    end
  end
  
  def test_pop
    a = []
    f = Fiber.new do
      loop do
        a << @q.pop
      end
    end
    
    3.times do
      op = f.resume
      assert_equal :block, op
      assert_equal [], a
    end
    
    @q.entries.concat (0...10).to_a
    
    op = f.resume
    assert_equal :block, op
    assert_equal a, (0...10).to_a
  end
end
