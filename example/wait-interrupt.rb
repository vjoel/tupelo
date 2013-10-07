# This example shows how a transaction can be used to wait for some event,
# but interrupt the wait when some other event happens.

require 'tupelo/app'

Tupelo.application do
  child do
    log.progname = "host"

    transaction do
      mode = read(mode: nil)["mode"]
      log "waiting for visitor to arrive by #{mode}"
      read ["visitor arrives"]
    end

    log "welcome!"
  end
  
  child do
    log.progname = "visitor"

    log "I think i am coming by train"
    write_wait mode: "train"
    sleep 1

    log "changing my mind, coming by plane"
    transaction {take mode: nil; write mode: "plane"}
    sleep 1

    log "changing my mind again, coming by car"
    transaction {take mode: nil; write mode: "car"}
    sleep 1

    log "hello!"
    write_wait ["visitor arrives"]
  end
end

