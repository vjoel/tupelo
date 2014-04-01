class Tupelo::Client
  def define_event_subspace
    define_subspace("event", {
    # field         type        description
    #                           (from http://riemann.io/concepts.html)

      host:         String,   # A hostname, e.g. "api1", "foo.com"

      service:      String,   # e.g. "API port 8000 reqs/sec"

      state:        String,   # Any string less than 255 bytes, e.g. "ok",
                              # "warning", "critical"

      time:         Numeric,  # The time of the event, in unix epoch seconds

      description:  String,   # Freeform text

      tags:         Array,    # Freeform list of strings,
                              # e.g. ["rate", "fooproduct", "transient"]

      metric:       Numeric,  # A number associated with this event,
                              # e.g. the number of reqs/sec.

      ttl:          Numeric,  # A floating-point time, in seconds, that this
                              # event is considered valid for. Expired states
                              # may be removed from the index.

      custom:       Hash      # Arbitrary key-value pairs (not just strings).
    })
  end

  # This could be a subspace of the event subspace, but for now, we can just
  # use it as a template to select critical events out of the event subspace.
  CRITICAL_EVENT = {
    host:         nil,
    service:      nil,
    state:        /\A(?:critical|fatal)\z/i,
    time:         nil,
    description:  nil,
    tags:         nil,
    metric:       nil,
    ttl:          nil,
    custom:       nil
  }.freeze

  # Also could be a subspace of the event subspace, but for now, we can just
  # use it as a template to select expired events out of the event subspace.
  EXPIRED_EVENT = {
    host:         nil,
    service:      nil,
    state:        /\Aexpired\z/i,
    time:         nil,
    description:  nil,
    tags:         nil,
    metric:       nil,
    ttl:          nil,
    custom:       nil
  }.freeze
end
