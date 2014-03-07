# How to deduplicate a tuple.
#
# Problem: we have some clients, each of which writes the same tuple.
# How can we remove duplicates?
#
# Run with --trace to see how this works.

require 'tupelo/app'

N_CLIENTS = 5

T = [1] # whatever

Tupelo.application do
  N_CLIENTS.times do
    child do
      unless read_nowait T  # try not to write dups, but...
        write_wait T        # T is possibly not unique
      end

      # After writing T, each client tries to reduce the T population to one
      # tuple.
      catch do |done|
        loop do
          transaction do
            if take_nowait T and take_nowait T
              write T
            else
              throw done # don't take or write anything
            end
          end
        end
      end

      # At the tick on which the last transaction above from this client
      # completes, there is a unique T, but of course that may change in the
      # future, for example, if another client's `write_wait T` was delayed in
      # flight over the network). But in that case, the other client will also
      # perform the same de-dup code.

      count = read_all(T).size
      log "count = #{count}"
    end
  end
end
