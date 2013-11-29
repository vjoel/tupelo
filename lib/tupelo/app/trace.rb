require 'tupelo/app'

# displays every transaction in sequence, specially marking failed ones,
# until INT signal
class Tupelo::AppBuilder
  def start_trace
    child passive: true do |client|
      trap :INT do
        exit!
      end

      note = client.notifier
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
  end
end
