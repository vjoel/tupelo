# A tupelo cluster may expose its services using some other protocol so that
# process need not be tupelo-aware to use them. This example expands on the
# http.rb example and shows how to use tupelo to coordinate multiple sinatra
# instances.
#
# Depends on the sinatra and http gems.

PORTS = [9001, 9002 , 9003]

fork do
  require 'tupelo/app'
  
  Tupelo.application do
    PORTS.each do |port|
      child do |client|
        require 'sinatra/base'

        Class.new(Sinatra::Base).class_eval do
          get '/' do
            "hello, world\n"
          end

          post '/send' do
            text = params["text"]
            dest = params["dest"]
            client.write ["message", dest, text]
              ## should use subspaces and a data structure that keeps
              ## messages in order
          end
          
          get '/recv' do
            dest = params["dest"]
            _, _, text = client.take ["message", dest, String]
            text
          end

          get '/exit' do
            Thread.new {sleep 1; exit}
            "bye\n"
          end

          set :port, port
          run!
        end
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

  # For simplicity, one http client per http server
  http_clients = PORTS.map.with_index do |port, i|
    {
      server_url: "http://localhost:#{port}",
      id:         i
    }
  end

  http_clients.each_with_index do |http_client|
    fork do
      url = http_client[:server_url]
      print "trying server at #{url}"
      begin
        print "."
        HTTP.get url
      rescue Errno::ECONNREFUSED
        sleep 0.2
        retry
      end

      other = (http_client[:id] + 1) % http_clients.size
      me = http_client[:id]

      puts
      HTTP.post "#{url}/send?dest=#{other}&text=hello_from_#{me}"
      text = HTTP.get "#{url}/recv?dest=#{me}"
      puts "http client #{me} got: #{text}\n"
      HTTP.get "#{url}/exit"
    end
  end
end

Process.waitall
