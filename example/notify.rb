# See also bin/tspy

require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    Thread.new do
      note = client.notifier
      client.write ["start"]

      client.log "%10s %10s %10s %s" % %w{ status tick client operation }
      loop do
        status, global_tick, client_id, op = note.wait
        client.log "%10s %10d %10d %p" % [status, global_tick, client_id, op]
      end
    end

    client.take ["finish"]
  end
  
  app.child do |client|
    client.take ["start"]

    client.write [1, 2]
    client.write [3, 4]
    client.write foo: "bar", baz: ["zap"]
    
    client.transaction do |t|
      x, y = t.take [Numeric, Numeric]
      t.write [x, y, x + y]
    end
    
    client.write ["finish"]
  end
end
