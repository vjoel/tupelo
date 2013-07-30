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
      puts "%6s %6s %6s %s" % %w{ tick cid status operation }
      loop do
        status, tick, cid, op = note.wait
        unless status == :attempt
          s = status == :failure ? "FAIL" : ""
          puts "%6d %6d %6s %p" % [tick, cid, s, op]
        end
      end
    end
  end
end
