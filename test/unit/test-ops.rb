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
    r = [0]; w = [1]; t = [2]
    cl = make_clients(2)

    wr = cl[0].write r, t
    cl[0].update; assert_equal 1, wr.global_tick
    
    trans = Fiber.new do
      cl[1].transaction do |tr|
        tr.write w
        [tr.read(r), tr.take(t)]
      end
    end
    trans.resume

    cl[1].update; trans.resume
    cl[1].update; trans.resume
    cl[1].update; assert_equal [r, t], trans.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_equal [r, w], reader.resume
    end
  end
  
  def test_transaction_waiting
    r = [0]; w = [1]; t = [2]
    cl = make_clients(2)

    trans = Fiber.new do
      cl[1].transaction do |tr|
        tr.write w
        [tr.read(r), tr.take(t)]
      end
    end
    trans.resume

    wr = cl[0].write r, t
    cl[0].update; assert_equal 1, wr.global_tick
    
    cl[1].update; trans.resume
    cl[1].update; trans.resume
    cl[1].update; assert_equal [r, t], trans.resume
    cl[0].update

    cl.each do |c|
      reader = Fiber.new { c.read_all [nil] }; reader.resume
      c.update; assert_equal [r, w], reader.resume
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
  
  def test_transaction_fail_retry
    winner, loser = make_clients(2)
    winner.write ["token", 1]; winner.update; loser.update
    
    run_count = 0
    result = nil
    lose_ops = Fiber.new do
      result = loser.transaction do
        run_count += 1
        a = []
        write ["test",  1]
        a << (take  ["token", 1])
        write ["test",  2]
        a << (take  ["token", 2])
        write ["test",  3]
        a
      end
    end
    
    lose_ops.resume; loser.update # taking token 2
    lose_ops.resume; loser.update # blocked on take token 2
    assert_equal 1, run_count
    
    win_ops = Fiber.new do
      winner.take ["token", 1]
    end
    
    winner.update; win_ops.resume
    winner.update; win_ops.resume
    winner.update; win_ops.resume

    loser.update; lose_ops.resume
    assert_equal 2, run_count

    winner.update
    win_ops = Fiber.new do
      winner.read_all [nil, nil]
    end
    win_ops.resume; winner.update
    assert_equal [], win_ops.resume

    win_ops = Fiber.new do
      winner.write ["token", 2]
    end
    winner.update; win_ops.resume; winner.update
    
    loser.update
    assert_equal :block, lose_ops.resume
    
    win_ops = Fiber.new do
      winner.write ["token", 1]
    end
    winner.update; win_ops.resume; winner.update
    
    loser.update; lose_ops.resume
    loser.update; lose_ops.resume
    loser.update
    assert_equal [["token", 1], ["token", 2]], lose_ops.resume
    
    winner.update
    win_ops = Fiber.new do
      winner.read_all [nil, nil]
    end
    win_ops.resume; winner.update
    assert_equal [["test", 1], ["test", 2], ["test", 3]], win_ops.resume
  end
  
  def test_pulse
    t = ["c0"]
    cl = make_clients(2)

    reader = Fiber.new { cl[1].read [nil] }; reader.resume

    cl[0].pulse t
    cl[0].update
    cl[1].update; assert_equal t, reader.resume
    
    reader = Fiber.new { cl[1].read_nowait [nil] }; reader.resume
    cl[1].update; assert_equal nil, reader.resume
  end
end
