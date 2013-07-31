# Stresses the ability of the archiver to handle highl load, and in particular
# situations where the client asks for data more recent than what the archiver
# has received.

require 'tupelo/app'

N = 100

Tupelo.application do
  N.times do |i|
    sleep i/1000.0
    child do
      write [1]
    end
  end
end
