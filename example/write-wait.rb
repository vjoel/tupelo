require 'tupelo/app'

Tupelo.application do
  local do
    write [1]
    write [2]
    w = write [3]
    p read_all
    w.wait # wait for the write to come back and be applied to the client
    p read_all

    write [4]
    write [5]
    write_wait [6]
    p read_all
  end
end
