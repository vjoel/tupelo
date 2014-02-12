require 'tupelo/app'

class Tupelo::Client
  def trace_loop
    note = notifier
    log << ( "%6s %6s %6s %s\n" % %w{ tick cid status operation } )
    loop do
      status, tick, cid, op, tags = note.wait
      unless status == :attempt
        s = status == :failure ? "FAIL" : ""
        if tags and not tags.empty?
          log << ( "%6d %6d %6s %p to %p\n" % [tick, cid, s, op, tags] )
        else
          log << ( "%6d %6d %6s %p\n" % [tick, cid, s, op] )
        end
      end
    end
  end

  # Turn on tracing in this client (performed by a thread).
  def start_trace
    @trace_thread ||= Thread.new do
      begin
        trace_loop
      rescue => ex
        log "trace thread: #{ex}"
      end
    end
  end

  # Turn off tracing in this client.
  def stop_trace
    @trace_thread && @trace_thread.kill
  end
end

# displays every transaction in sequence, specially marking failed ones,
# until INT signal
class Tupelo::AppBuilder
  def start_trace
    child passive: true do
      trap :INT do
        exit!
      end

      trace_loop
    end
  end
end
