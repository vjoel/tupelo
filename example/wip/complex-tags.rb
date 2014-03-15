# Tags can be any object that can be serialized by msgpack. Strings and
# numbers are typical, but it can be useful to encode a bit more structure.
# In this case we can use a complex tag to limit communication to particular
# client groups (use groups of clients, so
# that the lifespan of one process does not affect the system as a whole).

require 'tupelo/app'

Tupelo.application do
  num_tag = "input numbers"#["input numbers", 1]
  str_tag = "input strings"#["input strings", 2]
  
  local do
    define_subspace num_tag, [Numeric]
    define_subspace str_tag, [String]
  end

  child subscribe: num_tag, passive: true do
    read subspace(num_tag) do |num, _|
      write [num.to_s]
    end
  end
  
  child subscribe: str_tag, passive: true do
    read subspace(str_tag) do |str, _|
      begin
        num = Integer(str) rescue Float(str)
        write [num]
      rescue 
      end
    end
  end

  local do # subscribed to everything
    write [42]
    write ["17.5"]

    count = 0
    read do |tuple|
      log tuple
      count += 1
      break if count == 4
    end
  end
end
