class Tupelo::Client
  # Expire old events.
  def run_expirer_v1
    scheduler = make_scheduler
    
    read subspace("event") do |event|
      next if event["state"] == "expired"

      event_exp = event["time"] + event["ttl"]
      scheduler.at event_exp do
        transaction do
          take event
          pulse event.merge("state" => "expired")
            # Not sure if this is riemann semantics. Using #pulse rather
            # that #write means that the expired event exists in the
            # space only while the transaction is executing, but that is
            # enough to trigger any client that is waiting on a template
            # that matches the event. Use the --debug-expiration switch
            # to see this happening (and use -v to make log messages
            # verbose, showing timestamps).
        end
      end
    end
  end
end
