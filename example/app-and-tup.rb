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
# ra # => [[5]]
# w [7.4]
# ra # => [[12.4]]

require 'tupelo/app'

filename = "servers-#$$.yaml"
puts "run this in another shell: tup #{filename}"

Tupelo.application servers_file: filename do
  child do
    loop do
      transaction do
        x, = take [Numeric]
        y, = take [Numeric]
        write [x + y]
      end
    end
  end
end
