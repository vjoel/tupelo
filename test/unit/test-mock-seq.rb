require 'minitest/autorun'

require 'mock-seq.rb'
require 'mock-msg.rb'

class TestMockSeq < Minitest::Test
  def setup
    @seq = MockSequencer.new
  end
  
  def test_multiple_streams
    clients = (0..1).map {|i| @seq.stream}
    
    count = 0
    expected = []
    clients.each_with_index do |c, i|
      (0..2).each do |j|
        c.write MockMessage[blob: [i,j]]
        count += 1
        expected << [count, i,j]
      end
    end

    clients.each_with_index do |c, i|
      assert_equal expected, c.map {|m| [m.global_tick, *m.blob]}
    end
  end
  
  def test_alternations_of_reads_and_writes
    client = @seq.stream
    client.write MockMessage[blob: 1]
    client.write MockMessage[blob: 2]
    assert_equal [1,2], client.map(&:blob)

    client.write MockMessage[blob: "a"]
    client.write MockMessage[blob: "b"]
    assert_equal ["a","b"], client.map(&:blob)
  end
end
