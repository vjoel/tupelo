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

      custom:       nil       # Any data
                              # (not quite same as riemann's custom event attrs,
                              # which are just arbitrary key-value pairs;
                              # tupelo does not permit wildcards in keys)
    })
  end
end
