# Use tupelo's scheduler to time out a transaction. See also timeout.rb.
# This has the advantage of using just one extra thread for all timeouts,
# rather than one thread per timeout.

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    result =
      begin
        client.transaction timeout: 1 do |t|
          t.take ["foo"]
        end
      rescue TimeoutError => ex
        ex
      end
    client.log "result = #{result.inspect}"
  end
end


