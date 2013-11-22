# A tupelo cluster may expose its services using some other protocol so that
# process need not be tupelo-aware to use them. This example uses http to expose
# a memcache-like service.
#
# Depends on the sinatra, json, and http gems.

require 'json'

fork do
  require 'tupelo/app'
  
  Tupelo.application do
    child do |client|
      require 'sinatra/base'

      Class.new(Sinatra::Base).class_eval do
        get '/' do
          "hello, world\n"
        end
        
        get '/read' do
          key = params["k"]
          resp = client.read ["memo", key, nil]
          resp.to_json + "\n"
        end

        get '/exit' do
          Thread.new {sleep 1; exit}
          "bye\n"
        end
        
        run!
      end
    end
    
    # this process does some imaginary super-important work whose results
    # need to be cached.
    child passive: true do
      100.times do |i|
        sleep 1
        write ["memo", i.to_s, Time.now.to_s]
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
  puts "Getting cached data as soon as available:"
  5.times do |i|
    resp = HTTP.get "#{url}/read?k=#{i}"
    p JSON.parse(resp)
  end

  puts
  puts "Reviewing already cached data:"
  5.times do |i|
    resp = HTTP.get "#{url}/read?k=#{i}"
    p JSON.parse(resp)
  end

  HTTP.get "#{url}/exit"
end

Process.waitall
