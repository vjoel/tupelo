# Same as chat.rb, but no messages are stored.

require 'tupelo/app'

svr = "chat-nohistory.yaml"

Thread.abort_on_exception = true

def display_message msg
  from, time, line = msg.values_at(*%w{from time line})
  time_str = Time.at(time).strftime("%I:%M:%S")
  print "\r\033[2K" # Esc[2K is "Clear entire line"
  puts "#{from}@#{time_str}> #{line}"
end

Tupelo.tcp_application servers_file: svr do
  me = argv.shift

  local do
    require 'readline'

    Thread.new do
      read from: nil, line: nil, time: nil do |msg|
        display_message msg
        Readline.refresh_line
      end
    end
    
    while line = Readline.readline("#{me}> ", true)
      pulse from: me, line: line, time: Time.now.to_f
    end
  end
end
