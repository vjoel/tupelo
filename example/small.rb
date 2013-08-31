# An example of using EasyServe directly (the hard way) rather than tupelo/app.
# See small-simplified.rb for the difference.

require 'easy-serve'

log_level = case
  when ARGV.delete("--debug"); Logger::DEBUG
  when ARGV.delete("--info");  Logger::INFO
  when ARGV.delete("--warn");  Logger::WARN
  when ARGV.delete("--error"); Logger::ERROR
  when ARGV.delete("--fatal"); Logger::FATAL
  else Logger::WARN
end

EasyServe.start(servers_file: "small-servers.yaml") do |ez|
  log = ez.log
  log.level = log_level
  log.progname = "parent"

  ez.start_servers do
    arc_to_seq_sock, seq_to_arc_sock = UNIXSocket.pair
    arc_to_cseq_sock, cseq_to_arc_sock = UNIXSocket.pair
    
    ez.server :seqd do |svr|
      require 'funl/message-sequencer'
      seq = Funl::MessageSequencer.new svr, seq_to_arc_sock, log: log,
        blob_type: 'msgpack' # the default
        #blob_type: 'marshal' # if you need to pass general ruby objects
        #blob_type: 'yaml' # less general ruby objects, but cross-language
        #blob_type: 'json' # more portable than yaml, but more restrictive
      seq.start
    end
    
    ez.server :cseqd do |svr|
      require 'funl/client-sequencer'
      cseq = Funl::ClientSequencer.new svr, cseq_to_arc_sock, log: log
      cseq.start
    end

    ez.server :arcd do |svr|
      require 'tupelo/archiver'
      arc = Tupelo::Archiver.new svr,
        seq: arc_to_seq_sock, cseq: arc_to_cseq_sock, log: log
      arc.start
    end
  end
  
  def run_client opts
    log = opts[:log]
    log.progname = "client <starting in #{log.progname}>"
    require 'tupelo/client'
    client = Tupelo::Client.new opts
    client.start do
      log.progname = "client #{client.client_id}"
    end
    yield client
  ensure
    client.stop if client # gracefully exit the tuplespace management thread
  end

  ez.child :seqd, :cseqd, :arcd do |seqd, cseqd, arcd|
    run_client seq: seqd, cseq: cseqd, arc: arcd, log: log do |client|
      client.write [2, 3, "frogs"]
      _, s = client.take ["animals", nil]
      puts s
    end
  end

  ez.child :seqd, :cseqd, :arcd do |seqd, cseqd, arcd|
    run_client seq: seqd, cseq: cseqd, arc: arcd, log: log do |client|
      x, y, s = client.take [Numeric, Numeric, String]
      s2 = ([s] * (x + y)).join(" ")
      client.write ["animals", s2]
    end
  end
end
