class MockSequencer
  attr_reader :messages

  def initialize
    @messages = []
  end

  def tick
    messages.size
  end

  def << message
    message = Marshal.load(Marshal.dump(message))
    message.global_tick = tick + 1
    message.delta = nil
    @messages << message
  end

  def [](i)
    @messages[i]
  end

  def stream
    Stream.new(self)
  end

  class Stream
    include Enumerable
    
    def initialize seq
      @seq = seq
      @read_tick = 0
    end

    def << message
      @seq << message
    end
    alias write <<

    def read
      @seq.messages[@read_tick].tap {|m| m and @read_tick += 1}
    end

    def each
      while message = read
        yield message
      end
    end
  end
end
