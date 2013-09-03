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
    assert_raises MockClient::IsDone do
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
  
  def test_run_until_blocked
    c = MockClient.new
    c.worker = MockWorker.new
    
    c.will do
      3.times do |i|
        Fiber.yield i
      end
      11.times do
        Fiber.yield :block
      end
      "done"
    end
    
    a = []
    c.run_until_blocked limit:10 do |val|
      a << val
    end
    
    assert_equal [0,1,2], a

    r = c.run
    assert_equal "done", r
  end

  def test_now
    c = MockClient.new
    c.worker = MockWorker.new
    
    result = c.now do
      3.times do
        Fiber.yield :block
      end
      "done"
    end
    
    assert_equal "done", result
  end
  
  def test_now_limit
    c = MockClient.new
    c.worker = MockWorker.new
    
    assert_raises MockClient::IsBlocked do
      c.now limit: 2 do
        3.times do
          Fiber.yield :block
        end
        "done"
      end
    end
  end
end
