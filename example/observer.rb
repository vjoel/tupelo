# An implementation of the observer pattern using transaction failure.
# Note that the failures happen in the pre-commit phase of the transactions,
# so they will not be shown with the --trace switch.
# Run with `--stream` to show the optional observer implemented using
# streaming reads instead of transaction failure.

require 'tupelo/app'

Tupelo.application do

  child do
    log.progname = "counting client"

    write count: 0

    3.times do
      sleep 1
      transaction do
        count = take(count: Numeric)["count"]
        write count: count + 1
        log "incrementing counter"
      end
    end
  end

  child passive: true do
    log.progname = "observing client"

    loop do
      begin
        t = transaction
        counter = t.read count: Numeric
        log "entering new state: #{counter}"
        t.wait
      rescue Tupelo::Client::TransactionFailure => ex
        log "leaving old state: #{counter}"
      end
    end
  end

  if argv.include?("--stream")
    # If you only care about seeing each new values as it arrives, this client
    # is enough. But it doesn't alert you when a tuple is deleted. In this
    # example, the delete and insert happen atomically in a transaction, so
    # it doesn't matter.
    child passive: true do
      log.progname = "stream client"

      read count: Numeric do |counter|
        log "entering new state: #{counter}"
      end
    end
  end

end
