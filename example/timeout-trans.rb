# Use tupelo's scheduler to time out a transaction. See also timeout.rb.
# This has the advantage of using just one extra thread for all timeouts,
# rather than one thread per timeout.

require 'tupelo/app'

Tupelo.application do
  child do
    result =
      begin
        transaction timeout: 1 do
          take ["foo"]
        end
      rescue TimeoutError => ex
        ex
      end
    log "This should be a timeout error: #{result.inspect}"
  end
end


