require 'minitest/autorun'

require 'mock-client.rb'

class TestMockClient < Minitest::Test
  class MockWorker
    def update
    end
  end
  
  def test_step
    c = MockClient.new
    c.worker = MockWorker.new
    
    c.will do
      3.times do |i|
        Fiber.yield i
      end
      "done"
    end

    assert_equal 0, c.step
    assert_equal 1, c.step
    assert_equal 2, c.step
    assert_equal "done", c.step
    assert_raises RuntimeError do
      c.step
    end
  end
  
  def test_run
    c = MockClient.new
    c.worker = MockWorker.new
    
    c.will do
      3.times do |i|
        Fiber.yield i
      end
      "done"
    end
    
    a = []
    r = c.run do |val|
      a << val
    end
    
    assert_equal "done", r
    assert_equal [0,1,2], a
  end
end
