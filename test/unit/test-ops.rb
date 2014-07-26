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
      c.tuplestore = Tupelo::Client::SimpleTupleStore
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

  def test_read_existing
    t = ["foo"]
    cl = make_clients(2)

    w = cl[0].now {write t}
    assert_equal 1, w.global_tick

    cl.each do |c|
      c.will {read [nil]}
      assert_equal t, c.run
    end
  end

  def test_read_waiting
    t = ["bar"]
    cl = make_clients(2)

    cl[1].will {read [nil]}.run_until_blocked

    w = cl[0].now {write t}
    assert_equal 1, w.global_tick

    assert_equal t, cl[1].run

    cl.each do |c|
      c.will {read [nil]}
      assert_equal t, c.run
    end
  end

  def test_read_stream
    writer, reader = make_clients(2)
    a = []
    n = 10; k = 3

    (0...k).each do |i|
      writer.now {write [i]}
    end

    reader.will {read([nil]){|t| a << t}}

    (0...k).each do |i|
      reader.run_until_blocked
      assert_equal [i], a[i]
    end

    assert_equal [0], a[0]
    (k...n).each do |i|
      writer.now {write [i]}
      reader.run_until_blocked
      assert_equal [i], a[i]
    end
  end

  def test_take_existing
    t = ["foo"]
    cl = make_clients(2)

    w = cl[0].now {write t}
    assert_equal 1, w.global_tick

    cl[1].will {take [nil]}
    assert_equal t, cl[1].run

    cl.each do |c|
      c.will {read_all [nil]}
      assert_empty c.run
    end
  end

  def test_take_waiting
    t = ["bar"]
    taker, writer = make_clients(2)

    taker.will {take [nil]}.run_until_blocked

    w = writer.now {write t}
    assert_equal 1, w.global_tick

    assert_equal t, taker.run

    [taker, writer].each do |c|
      c.will {read_all [nil]}
      assert_empty c.run
    end
  end

  def test_transaction_existing
    r = [0]; w = [1]; t = [2]
    writer, transactor = make_clients(2)

    w_op = writer.now {write r, t}
    assert_equal 1, w_op.global_tick

    transactor.will do
      transaction do
        write w
        [read(r), take(t)]
      end
    end

    assert_equal [r, t], transactor.run

    [writer, transactor].each do |c|
      c.will {read_all [nil]}
      assert_equal [r, w], c.run
    end
  end

  def test_transaction_waiting
    r = [0]; w = [1]; t = [2]
    writer, transactor = make_clients(2)

    transactor.will do
      transaction do
        write w
        [read(r), take(t)]
      end
    end
    transactor.run_until_blocked

    w_op = writer.now {write r, t}
    assert_equal 1, w_op.global_tick

    assert_equal [r, t], transactor.run

    [writer, transactor].each do |c|
      c.will {read_all [nil]}
      assert_equal [r, w], c.run
    end
  end

  def test_transaction_take_two
    x = [0]; y = [1]
    c = make_client(1)

    c.now {write x, y}

    c.will do
      transaction do
        [take([nil]), take([nil])]
      end
    end

    assert_equal [x, y].sort, c.run.sort
  end

  def test_transaction_take_read
    x = [0]
    c = make_client(1)

    c.now {write x}

    c.will do
      transaction do
        [take(x), read_nowait(x)]
      end
    end

    assert_equal [x, nil], c.run
  end

  def test_transaction_write_read
    x = [0]
    c = make_client(1)

    c.will do
      transaction do
        write(x); read(x)
      end
    end

    assert_equal x, c.run
  end

  def test_transaction_write_take
    x = [0]
    c = make_client(1)

    c.will do
      transaction do
        write(x); take(x)
      end
    end

    assert_equal x, c.run
  end

  def test_transaction_empty
    transactor = make_client(0)

    transactor.will do
      transaction do
      end
    end

    assert_equal nil, transactor.run
    assert_equal 0, transactor.worker.global_tick
  end

  def test_transaction_cancel
    w = [1]; t = [2]
    writer, transactor = make_clients(2)

    tr = nil
    transactor.will do
      tr = transaction
      tr.write w
      begin
        tr.take t
        tr.commit.wait
      rescue Tupelo::Client::TransactionAbort
        Fiber.yield :abort
      end
    end
    assert_equal :block,  transactor.step
    tr.cancel
    assert_equal :abort, transactor.step

    w_op = writer.now {write t}
    assert_equal 1, w_op.global_tick

    [writer, transactor].each do |c|
      c.will {read_all [nil]}
      assert_equal [t], c.run
    end
  end

  def test_transaction_fail_retry
    winner, loser = make_clients(2)
    winner.now {write ["token", 1]}

    run_count = 0
    result = nil
    loser.will do
      result = transaction do
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
    loser.run_until_blocked
    assert_equal 1, run_count

    winner.will do
      take ["token", 1]
    end
    winner.run
    loser.run_until_blocked

    assert_equal 2, run_count
    assert_empty winner.now {read_all [nil, nil]}

    winner.now {write ["token", 2]}
    assert_raises(MockClient::IsBlocked) {loser.run}

    winner.now {write ["token", 1]}
    assert_equal [["token", 1], ["token", 2]], loser.run

    result = winner.now {read_all [nil, nil]}
    assert_equal [["test", 1], ["test", 2], ["test", 3]], result
  end

  def test_pulse
    t = ["c0"]
    reader, pulser = make_clients(2)

    reader.will {read [nil]}.run_until_blocked
    pulser.now {pulse t}
    assert_equal t, reader.run
    assert_empty reader.now {read_all [nil]}
  end
end
