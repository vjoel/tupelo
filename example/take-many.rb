# This is a simple way to take multiple tuples at once.

require 'tupelo/app'

Tupelo.application do
  child do
    result = transaction { (1..3).map {|i| take [i]} }
    log result
  end
  
  child do
    write [2], [1], [3]
  end
end
