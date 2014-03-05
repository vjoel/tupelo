class Tupelo::Client
  def run_expiration_debugger
    read Tupelo::Client::EXPIRED_EVENT do |event|
      event_exp = event["time"] + event["ttl"]
      delta = Time.now.to_f - event_exp
      if delta > 0.1
        log.warn "expired late by %6.4f seconds: #{event}" % delta
      elsif delta < 0
        log.warn "expired too soon: #{event}"
      else
        log.info "expired on time: #{event}"
      end
    end
  end
end
