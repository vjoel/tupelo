# Network chat program.
#
# You can run several instances of chat.rb. The first will set up all needed
# services, as well as run the chat shell. The rest will connect by referring to
# the services specified in a yaml file, and then run the chat shell.
#
# Usage:
#
#   ruby chat.rb chat.yaml username
#
# For remote clients, you can copy the yaml file, or use scp syntax:
#
#   ruby chat.rb host:path/to/chat.yaml username
#
# The username is shared with other chat clients. New clients see a brief
# history of the chat, as well as new messages from other clients.
#
# Accepts usual tupelo switches (such as --trace, --debug, --tunnel).
#
# If the first instance is run with "--persist-dir <dir>", messages
# will persist across service shutdown.
#
# Compare: https://github.com/bloom-lang/bud/blob/master/examples/chat.
#
# To do: use a subspace with a sorted data structure, like rbtree or in-memory
# sqlite, for the messages.

require 'tupelo/app'

history_period = 60 # seconds -- discard _my_ messages older than this

Thread.abort_on_exception = true

def display_message msg
  from, time, line = msg.values_at(*%w{from time line})
  time_str = Time.at(time).strftime("%I:%M:%S")
  print "\r\033[2K" # Esc[2K is "Clear entire line"
  puts "#{from}@#{time_str}> #{line}"
end

Tupelo.tcp_application do
  me = argv.shift

  local do
    require 'readline'

    Thread.new do
      read from: nil, line: nil, time: nil do |msg|
        display_message msg
        Readline.refresh_line
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
