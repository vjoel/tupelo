require 'tupelo/app'
require 'tupelo/util/boolean'

Tupelo.application do
  local do
    tm = match_any [0..2, String], [3..5, Hash]
    
    write(
      [0, "a"], [1, {b: 0}], [2, "c"],
      [3, "a"], [4, {b: 0}], [5, "c"]
    ).wait

    log read_all tm
  end
end
