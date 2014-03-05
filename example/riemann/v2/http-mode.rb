# Run a web client -- depends only on http, not tupelo.
def start_web_client
  fork do
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
    puts HTTP.get "#{url}/read"
    HTTP.get "#{url}/exit"
  end
end

# Run a little API server using +client+ to access tupelo.
def run_web_server(client)
  require 'sinatra/base'
  require 'json'

  Class.new(Sinatra::Base).class_eval do
    get '/read' do
      host = params["host"] # nil is ok -- matches all hosts
      resp = client.read(
        host:         host,
        service:      nil,
        state:        nil,
        time:         nil,
        description:  nil,
        tags:         nil,
        metric:       nil,
        ttl:          nil,
        custom:       nil
      )
      resp.to_json + "\n"
    end
    ## need way to query by existence of tag

    get '/exit' do
      Thread.new {sleep 1; exit}
      "bye\n"
    end

    run!
  end
end
