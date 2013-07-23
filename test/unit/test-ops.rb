require 'minitest/autorun'
require 'logger'

require 'mock-seq.rb'
require 'mock-msg.rb'
require 'mock-client.rb'
require 'testable-worker.rb'

class TestOps < Minitest::Test
  attr_reader :seq, :sio, :log

  class MiniFormatter < Logger::Formatter # Based on EasyServe::EasyFormatter
    Format = "%s: %s: %s\n"

    def call(severity, time, progname, msg)
      Format % [severity[0..0], progname, msg2str(msg)]
    end
  end

  def setup
    @seq = MockSequencer.new
  end

  def make_client cid
    MockClient.new.tap do |c|
      c.client_id = cid
      c.log = Logger.new($stderr).tap do |log|
        log.level = Logger::WARN
        log.progname = cid
        log.formatter = MiniFormatter.new
      end
      c.blobber = Marshal
      c.tuplespace = Tupelo::Client::SimpleTuplespace
      c.message_class = MockMessage
      c.seq = seq.stream
      c.worker = TestableWorker.new(c)
    end
  end

  def make_clients n
    n.times.map {|i| make_client i}
  end
  
  def test_one_client
    client = make_client "one"

    client.update; writer = client.write_nowait [1]
    client.update; writer.wait
    client.update; assert_equal 1, writer.global_tick
    
    reader = Fiber.new do
      client.read [nil]
    end

    client.update; reader.resume
    client.update; assert_equal [1], reader.resume
  end
  
  def test_two_clients
    t = ["c0"]
    cl = make_clients(2)

    cl[0].write t

    cl.each do |c|
      reader = Fiber.new { c.read [nil] }; reader.resume
      c.update; assert_equal t, reader.resume
    end
  end

  def test_read_existing
    t = ["foo"]
    cl = make_clients(2)
    
    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    
    cl.each do |c|
      reader = Fiber.new { c.read [nil] }; reader.resume
      c.update; assert_equal t, reader.resume
    end
  end

  def test_read_waiting
    t = ["bar"]
    cl = make_clients(2)

    reader = Fiber.new { cl[1].read [nil] }; reader.resume

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    cl[1].update; assert_equal t, reader.resume

    cl.each do |c|
      reader = Fiber.new { c.read [nil] }; reader.resume
      c.update; assert_equal t, reader.resume
    end
  end

  def test_take_existing
    t = ["foo"]
    cl = make_clients(2)

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick

    taker = Fiber.new { cl[1].take [nil] }; taker.resume
    cl[1].update; taker.resume
    cl[1].update; assert_equal t, taker.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_empty reader.resume
    end
  end

  def test_take_waiting
    t = ["bar"]
    cl = make_clients(2)

    taker = Fiber.new { cl[1].take [nil] }; taker.resume
    cl[1].update; taker.resume
    cl[1].update; assert_equal :block, taker.resume

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    cl[1].update; taker.resume
    cl[1].update; assert_equal t, taker.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_empty reader.resume
    end
  end
  
  def test_transaction_existing
    w = [1]; t = [2]
    cl = make_clients(2)

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    
    trans = Fiber.new do
      cl[1].transaction do |tr|
        tr.write w
        tr.take t
      end
    end
    trans.resume

    cl[1].update; trans.resume
    cl[1].update; assert_equal t, trans.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_equal [w], reader.resume
    end
  end
  
  def test_transaction_waiting
    w = [1]; t = [2]
    cl = make_clients(2)

    trans = Fiber.new do
      cl[1].transaction do |tr|
        tr.write w
        tr.take t
      end
    end
    trans.resume

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    
    cl[1].update; trans.resume
    cl[1].update; assert_equal t, trans.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_equal [w], reader.resume
    end
  end
  
  def test_transaction_cancel
    w = [1]; t = [2]
    cl = make_clients(2)

    tr = nil
    trans = Fiber.new do
      tr = cl[1].transaction
      tr.write w
      begin
        tr.take t
        tr.commit.wait
      rescue Tupelo::Client::TransactionAbort
        Fiber.yield :abort
      end
    end
    cl[1].update; assert_equal :block, trans.resume
    
    tr.cancel
    cl[1].update; assert_equal :abort, trans.resume

    wr = cl[0].write t
    cl[0].update; assert_equal 1, wr.global_tick
    cl[1].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_equal [t], reader.resume
    end
  end
  
  ## test Transaction#read
  ## test failure
  ## test pulse
  ## test optimistic
end
