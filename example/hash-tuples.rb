# Tuples can be sets of key-value pairs, rather than arrays.
#
# Caution:
#
# - when blob_type is json, (by using the --json switch, or by passing
#   blob_type: 'json' to #application), the keys of these hashes must be
#   strings. That's just a JSON thing.
#
# - ruby has some syntax quirks:
#
#   - these are the same
#        write foo: 1, bar: 2
#        write({foo: 1, bar: 2})
#     but this is a syntax error:
#        write {foo: 1, bar: 2}
#
#   - {x: 1} is short for {:x => 1}, rather than {"x" => 1}
#
#     tupelo kind of hides this issue: you can use {x: 1} as a template
#     to match tuples like {"x" => 1}. And you can write tuples using
#     either notation. However, the tuple will still behave like this:
#
#       write x: 1
#       t = take x: nil
#       t["x"] == 1 # ==> true
#       t[:x] == 1  # ==> false
#
#     In future API, it might be possible to access values like this:
#
#       t.x == 1    # ==> true
#
# - matching ops succeed only if the key sets are equal, so
#   you have to read or take using a template that has the same keys as the
#   target tuple -- see below.

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write x: 1, y: 2
  end
  
  app.child do |client|
    t = client.take x: Numeric, y: Numeric
    client.write x: t["x"], y: t["y"], sum: t["x"] + t["y"]
    client.log "sum result: #{client.read x: nil, y: nil, sum: nil}"
    
    # N.B.: these are all empty, for the reason given above.
    client.log client.read_all x: nil
    client.log client.read_all y: nil
    client.log client.read_all x: nil, y: nil, z: nil
  end
end
