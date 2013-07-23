class Foo
  attr_accessor :x

  # This method is necessary for #take to work correctly.
  def == other
    other.class == Foo and other.x == x
  end
end

require 'tupelo/app'

# Must use marshal or yaml -- msgpack and json do not support custom classes.
Tupelo.application blob_type: 'marshal' do |app|
  app.child do |client|
    f = Foo.new; f.x = 3
    p f

    client.write [f]

    p client.read [nil]
    p client.read [Foo]
    p client.read [f]

    p client.take [Foo]

    client.write [f]
    p client.take [f]
  end  
end
