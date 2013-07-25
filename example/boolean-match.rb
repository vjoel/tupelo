require 'tupelo/app'
require 'tupelo/util/boolean'

Tupelo.application do |app|
  app.local do |client|
    tm = client.match_any [0..2, String], [3..5, Hash]
    
    client.write(
      [0, "a"], [1, {b: 0}], [2, "c"],
      [3, "a"], [4, {b: 0}], [5, "c"]
    ).wait

    client.log client.read_all tm
  end
end
