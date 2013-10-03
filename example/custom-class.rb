class Foo
  attr_accessor :x

  # This method is necessary for #take to work correctly.
  def == other
    other.class == Foo and other.x == x
  end
end

require 'tupelo/app'

# Must use marshal or yaml -- msgpack and json do not support custom classes.
Tupelo.application blob_type: 'marshal' do
  child do
    f = Foo.new; f.x = 3
    p f

    write [f]

    p read [nil]
    p read [Foo]
    p read [f]

    p take [Foo]

    write [f]
    p take [f]
  end  
end
