require 'tupelo/app'
require_relative 'poi-client'

Tupelo.application do
  local do
    POISPACE = PoiStore.define_poispace(self)
  end

  child PoiClient, poispace: POISPACE, passive: true do
    log.progname = "poi-store"
    
    # At this point, the client already accepts writes in the space and stores
    # them in a sqlite table. For the sake of a simple example, we add
    # one feature to this mix: just show everything for each new tuple
    read do
      log read_all
    end
  end
  
  child subscribe: nil do
    write lat: 1.2, lng: 3.4, desc: "foo"
    sleep 0.5 # delay to make the demo interesting
    write lat: 5.6, lng: 7.8, desc: "bar"
    sleep 0.5
    write lat: 1.2, lng: 3.4, desc: "foo" # dup is ok
    sleep 0.5
  end
end
