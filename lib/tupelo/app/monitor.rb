require 'tupelo/app'

# displays every transaction in sequence, specially marking failed ones,
# until INT signal
class Tupelo::AppBuilder
  def start_monitor
    child do |client|
      trap :INT do
        exit!
      end

      note = client.notifier
      puts "%4s %4s %10s %s" % %w{ tick cid status operation }
      loop do
        status, tick, cid, op = note.wait
        unless status == :attempt
          s = status == :failure ? "FAILED" : ""
          puts "%4d %4d %10s %p" % [tick, cid, s, op]
        end
      end
    end
  end
end
