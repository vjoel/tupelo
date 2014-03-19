require 'tupelo/app'
require_relative 'poi-client'

Tupelo.application do
  local do
    POISPACE = PoiStore.define_poispace(self)
    define_subspace("cmd", {id: nil, cmd: String, arg: nil})
    define_subspace("rsp", {id: nil, result: nil})
      # Note: this id is request id, not related to sqlite table id.
  end

  child PoiClient, poispace: POISPACE, subscribe: "cmd", passive: true do
    log.progname = "poi-store #{client_id}"
    
    poispace = subspace("poi")
      # get local copy to replace poispace argument, which has wrong kind of
      # keys (string, not symbol)

    # handle custom queries here, using poi template
    loop do
      req = take subspace("cmd")
      case req[:cmd]
      when "find box"
        arg = req[:arg] ## should validate args
        lat = arg[:lat]; lng = arg[:lng]
        template = PoiTemplate.new(poi_template: poispace,
          lat: lat[0]..lat[1], lng: lng[0]..lng[1])
        write id: req[:id], result: read_all(template)

      when "delete box"
        arg = req[:arg]
        lat = arg[:lat]; lng = arg[:lng]
        template = PoiTemplate.new(poi_template: poispace,
          lat: lat[0]..lat[1], lng: lng[0]..lng[1])

        deleted = []
        transaction do
          while poi = take_nowait(template)
            log "preparing to delete: #{poi}"
            deleted << poi
          end
          # Wrapping this in a transaction not really necessary, but more
          # efficient (only one round-trip to network). Watch out for huge sets
          # of tuples, though.
        end

        write id: req[:id], result: deleted
      end
    end
  end
  
  child subscribe: "rsp" do
    write lat: 1.2, lng: 3.4, desc: "foo"
    write lat: 5.6, lng: 7.8, desc: "bar"
    write lat: 1.2, lng: 3.4, desc: "foo" # dup is ok
    write lat: 1.3, lng: 3.5, desc: "baz"
    
    cmd_id = 0 # manually managing cmd id is a pain!

    log "finding in box"
    cmd_id += 1
    req_id = [client_id, cmd_id]
    write id: req_id, cmd: "find box", arg: {lat: [1.0, 1.4], lng: [3.0, 4.0]}
    rsp = take id: req_id, result: nil
    log "result: #{rsp["result"]}"

    log "deleting in box"
    cmd_id += 1
    req_id = [client_id, cmd_id]
    write id: req_id, cmd: "delete box", arg: {lat: [1.0, 1.4], lng: [3.0, 4.0]}
    rsp = take id: req_id, result: nil
    log "result: #{rsp["result"]}"

    log "finding in box"
    cmd_id += 1
    req_id = [client_id, cmd_id]
    write id: req_id, cmd: "find box", arg: {lat: [1.0, 1.4], lng: [3.0, 4.0]}
    rsp = take id: req_id, result: nil
    log "result: #{rsp["result"]}"

    log "finding in BIGGER box"
    cmd_id += 1
    req_id = [client_id, cmd_id]
    write id: req_id, cmd: "find box", arg: {lat: [0, 100], lng: [0, 100]}
    rsp = take id: req_id, result: nil
    log "result: #{rsp["result"]}"
  end
end
