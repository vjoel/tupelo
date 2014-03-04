class Tupelo::Client
  # Expire old events. Uses a scheduler (which is a thread plus an rbtree)
  # to keep track of the expiration times and events.
  def run_expirer_v1
    scheduler = make_scheduler
    
    read subspace("event") do |event|
      next if event["state"] == "expired"

      event_exp = event["time"] + event["ttl"]
      scheduler.at event_exp do
        transaction do
          take_nowait event or break
            # Be cautious, in case of other expirer. If you can rule out
            # this possibility, then `take event` is fine.
          pulse event.merge("state" => "expired")
            # Not sure if this is riemann semantics. Using #pulse rather
            # than #write means that the expired event exists in the
            # space only while the transaction is executing, but that
            # momentary existence is enough to trigger any client that
            # is waiting on a template that matches the event. Use the
            # --debug-expiration switch to see this happening (and use
            # -v to make log messages verbose, showing timestamps).
        end
      end
    end
  end
end
