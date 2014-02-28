class Tupelo::Client
  def base_event
    @base_event ||= {
      host:         `hostname`.chomp,
      service:      "process #$$",
      state:        "",
      time:         0,
      description:  "",
      tags:         [],
      metric:       0,
      ttl:          0,
      custom:       nil
    }.freeze
  end

  def write_event event
    if event[:ttl] == 0.0
      pulse event # no need to bother with expiration
    else
      write event
    end

    log.info "created event #{event}"
  end

  # Generate some events.
  def run_producer i
    e_ok = base_event.merge(
      service:  "service #{i}",
      state:    "ok",
      time:     Time.now.to_f,
      ttl:      0.2
    )
    write_event e_ok

    e_cpu = base_event.merge(
      service:  "service #{i}",
      state:    "ok",
      time:     Time.now.to_f,
      ttl:      0.2,
      tags:     ["cpu", "cumulative"],
      metric:   Process.times.utime + Process.times.stime
    )
    write_event e_cpu

    sleep 0.5
      # Make sure whole set of processes stay alive long enough to see
      # expiration happen.
  end
end
