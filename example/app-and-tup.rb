# It's very easy to connect tup to an existing app.
# Just run this file, and then do (in another terminal):
#
# ../bin/tup servers-nnnn.yaml
#
# where nnnn is determined by looking in this dir. You can also
# set the filename explicitly (first ARGV), rather than let it be generated
# based on PID.
#
# Then, in tup, you can write [Numeric] tuples and they get summed:
#
# w [2]
# w [3]
# ra [nil] # => [[5]]
# w [7.4]
# ra [nil] # => [[12.4]]

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    loop do
      client.transaction do |t|
        x, = t.take [Numeric]
        y, = t.take [Numeric]
        t.write [x + y]
      end
    end
  end
end
