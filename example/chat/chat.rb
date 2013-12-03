# Accepts usual tupelo switches (such as --trace, --debug), plus one argument: a
# user name to be shared with other chat clients. New clients see a brief
# history of the chat, as well as new messages from other clients.
#
# You can run several instances of chat.rb. The first will set up all needed
# services. The rest will connect by referring to a yaml file in the same dir.
# Copy that file to remote hosts (and modify hostnames as needed) for remote
# access. If the first instance is run with "--persist-dir <dir>", messages
# will persist across service shutdown.
#
# Compare: https://github.com/bloom-lang/bud/blob/master/examples/chat.
#
# To do: use a subspace with a sorted data structure, like rbtree or in-memory
# sqlite, for the messages.

require 'tupelo/app'

svr = "chat.yaml"
history_period = 60 # seconds -- discard _my_ messages older than this

Thread.abort_on_exception = true

def display_message msg
  from, time, line = msg.values_at(*%w{from time line})
  time_str = Time.at(time).strftime("%I:%M.%S")
  puts "#{from}@#{time_str}> #{line}"
end

Tupelo.tcp_application servers_file: svr do
  me = argv.shift

  local do
    require 'readline'

    Thread.new do
      seen_at_start = {}
      read_all(from: nil, line: nil, time: nil).
        sort_by {|msg| msg["time"]}.
        each {|msg| display_message msg; seen_at_start[msg] = true}
      
      read from: nil, line: nil, time: nil do |msg|
        next if msg["from"] == me or seen_at_start[msg]
        print "\r"; display_message msg
        Readline.redisplay ### why not u work?
      end
    end
    
    Thread.new do
      loop do
        begin
          t = Time.now.to_f - history_period
          take({from: me, line: nil, time: 0..t}, timeout: 10)
        rescue TimeoutError
        end
      end
    end

    while line = Readline.readline("#{me}> ", true)
      write from: me, line: line, time: Time.now.to_f
    end
  end
end
