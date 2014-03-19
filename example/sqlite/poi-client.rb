require 'tupelo/client'
require_relative 'poi-store'

class PoiClient < Tupelo::Client
  def initialize *args, poispace: nil, subscribe: [], **opts
    super *args, **opts,
      tuplestore: [PoiStore, poispace.spec],
      subscribe: [poispace.tag] + [subscribe].flatten,
      symbolize_keys: true # for ease of use with sequel DB interface
  end
end
