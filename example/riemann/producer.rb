class Tupelo::Client
  # Generate some events.
  def run_producer i
    event = {
      host:         `hostname`.chomp,
      service:      "service #{i}",
      state:        "",
      time:         0,
      description:  "",
      tags:         [],
      metric:       0,
      ttl:          0,
      custom:       nil
    }.freeze

    e_ok = event.merge(
      state:    "ok",
      time:     Time.now.to_f,
      ttl:      0.2
    )

    if e_ok[:ttl] == 0.0
      pulse e_ok # no need to bother with expiration
    else
      write e_ok
    end
    
    log "created event #{e_ok}"
    
    sleep 0.5 # Let it expire
  end
end
