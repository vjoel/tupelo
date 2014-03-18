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
# gem install sequel sqlite3

require 'tupelo/app'
require_relative 'poi-store'

Tupelo.application do
  local do
    POISPACE = PoiStore.define_poispace(self)
  end

  child tuplespace: [PoiStore, POISPACE], subscribe: "poi",
        symbolize_keys: true, passive: true do
    log.progname = "poi-store"
    # handle custom queries here, using poi template
    read do
      log read_all # just show everything for each new tuple
    end
  end
  
  child subscribe: nil do
    write_wait lat: 12, lng: 34, desc: "foo"
    sleep 0.5 # give poi store time to store and log
    write_wait lat: 56, lng: 78, desc: "bar"
    sleep 0.5 # give poi store time to store and log
    write_wait lat: 12, lng: 34, desc: "foo" # dup is ok
    sleep 0.5 # give poi store time to store and log
  end
end
