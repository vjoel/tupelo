# A tupelo cluster may expose its services using some other protocol so that
# process need not be tupelo-aware to use them. This example uses drb to expose
# services, but http or plain sockets would work too.

require 'drb'

rd, wr = IO.pipe # just for sharing the drb uri (or we could hardcode it)

fork do
  rd.close
  require 'tupelo/app'
  
  Tupelo.application do
    child do
      DRb.start_service("druby://localhost:0", self)
      wr.puts DRb.uri; wr.close
      read ["done"]
    end
    
    child passive: true do
      loop do
        transaction do
          _, x, y = take ["request", nil, nil]
          write ["response", x, y, x + y]
        end
      end
    end
  end
end

fork do # No tupelo in this process.
  wr.close
  uri = rd.gets.chomp; rd.close
  DRb.start_service(nil, nil)
  tup_client = DRbObject.new(nil, uri)

  tup_client.write ["request", 3, 4]
  p tup_client.take ["response", 3, 4, nil]

  tup_client.write ["request", "foo", "bar"]
  p tup_client.take ["response", "foo", "bar", nil]

  tup_client.write ["request", ["a", "b"], ["c", "d"]]
  p tup_client.take ["response", ["a", "b"], ["c", "d"], nil]

  tup_client.write ["done"]
end

Process.waitall
