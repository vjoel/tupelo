# See also bin/tspy and the --trace switch on all tupelo apps and examples.

require 'tupelo/app'

Tupelo.application do
  child do
    Thread.new do
      note = notifier
      write ["start"]

      log "%10s %10s %10s %s" % %w{ status tick client operation }
      loop do
        status, global_tick, client_id, op = note.wait
        log "%10s %10d %10d %p" % [status, global_tick, client_id, op]
      end
    end

    take ["finish"]
  end
  
  child do
    take ["start"]

    write [1, 2]
    write [3, 4]
    write foo: "bar", baz: ["zap"]
    
    transaction do
      x, y = take [Numeric, Numeric]
      write [x, y, x + y]
    end
    
    write ["finish"]
  end
end
