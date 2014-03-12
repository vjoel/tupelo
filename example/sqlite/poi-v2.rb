# POI -- Points Of Interest
#
# This example creates a sqlite db in memory with a table of locations and
# descriptions of points of interest, and attaches the db to a subspace of the
# tuplespace. The process which manages that subspace can now do two things:
#
# 1. accept inserts (via write)
#
# 2. custom queries, accessed by write to a different subspace
#
# You can have redundant instances of this, and that will distribute load
# in #2 above.
#
# See example/subspaces/addr-book.rb for more comments on the command/response
# subspace pattern.
#
# gem install sequel sqlite3

require 'tupelo/app'
require_relative 'poi-store'

Tupelo.application do
  local do
    POISPACE = PoiStore.define_poispace(self)
    define_subspace("cmd", {id: nil, cmd: String, arg: nil})
    define_subspace("rsp", {id: nil, result: nil})
  end

  child tuplespace: [PoiStore, POISPACE],
        subscribe: ["poi", "cmd"], passive: true do
    log.progname = "poi-store #{client_id}"

    # handle custom queries here, using poi template
    loop do
      req = take subspace("cmd")
      case req["cmd"]
      when "find box"
        arg = req["arg"] ## validate this
        lat = arg["lat"]; lng = arg["lng"]
        template = PoiTemplate.new(poispace: subspace("poi"),
          lat: lat[0]..lat[1], lng: lng[0]..lng[1])
        write id: req["id"], result: read_all(template)
      end
    end
  end
  
  child subscribe: "rsp" do
    write lat: 12, lng: 34, desc: "foo"
    write lat: 56, lng: 78, desc: "bar"
    write lat: 12, lng: 34, desc: "foo" # dup is ok
    write lat: 13, lng: 35, desc: "baz"
    
    req_id = [client_id, 1]
    write id: req_id, cmd: "find box", arg: {lat: [10, 14], lng: [30, 40]}
    rsp = take id: req_id, result: nil
    log rsp["result"]
  end
end
