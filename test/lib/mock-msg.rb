class MockMessage
  attr_accessor :client_id
  attr_accessor :local_tick
  attr_accessor :global_tick
  attr_accessor :delta
  attr_accessor :tags
  attr_accessor :blob

  def initialize(*args)
    @client_id, @local_tick, @global_tick, @delta, @tags, @blob = *args
  end

  def self.[](
    client: nil, local: nil, global: nil, delta: nil, tags: nil, blob: nil)
    new client, local, global, delta, tags, blob
  end

  def inspect
    d = delta ? "+#{delta}" : nil
    t = tags ? " #{tags}" : nil
    s = [
      "client #{client_id}",
      "local #{local_tick}",
      "global #{global_tick}#{d}"
    ].join(", ")
    "<Message: #{s}#{t}>"
  end

  def to_a
    [@client_id, @local_tick, @global_tick, @delta, @tags, @blob]
  end

  def == other
    other.kind_of? self.class and
      @client_id = other.client_id and
      @local_tick = other.local_tick and
      @global_tick = other.global_tick and
      @delta = other.delta and
      @tags = other.tags and
      @blob = other.blob
  end
  alias eql? ==

  def hash
    @client_id.hash ^ @local_tick.hash ^ @global_tick.hash
  end
end
