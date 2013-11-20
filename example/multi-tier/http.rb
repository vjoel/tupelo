# A tupelo cluster may expose its services using some other protocol so that
# process need not be tupelo-aware to use them. This example uses http to expose
# services.
#
# Depends on the sinatra and http gems.

fork do
  require 'tupelo/app'
  
  Tupelo.application do
    child do |client|
      require 'sinatra/base'

      Class.new(Sinatra::Base).class_eval do
        get '/' do
          "hello, world\n"
        end
        
        get '/add' do
          x = Float(params["x"])
          y = Float(params["y"])
          client.write ["request", x, y]
          resp = client.take ["response", x, y, nil]
          resp.inspect + "\n"
        end

        get '/exit' do
          Thread.new {sleep 1; exit}
          "bye\n"
        end
        
        run!
      end
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
  require 'http'

  url = 'http://localhost:4567'

  print "trying server at #{url}"
  begin
    print "."
    HTTP.get url
  rescue Errno::ECONNREFUSED
    sleep 0.2
    retry
  end

  puts
  puts HTTP.get "#{url}/add?x=1&y=2"
  puts HTTP.get "#{url}/add?x=3.14&y=10"
  HTTP.get "#{url}/exit"
end

Process.waitall
