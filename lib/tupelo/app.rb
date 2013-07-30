require 'easy-serve'
require 'tupelo/client'

## this could be unified with the implementation of bin/tup, which is similar

module Tupelo
  # Not an essential part of the library, but used to build up groups of
  # processes for use in examples, tests, benchmarks, etc.
  class AppBuilder
    attr_reader :ez

    # Does this app own (as child processes) the seq, cseq, and arc servers?
    attr_reader :owns_servers

    def initialize ez, owns_servers: nil
      @ez = ez
      @owns_servers = owns_servers
    end

    def log
      ez.log
    end

    # Yields a client that runs in this process.
    def local client_class = Client, &block
      ez.local :seqd, :cseqd, :arcd do |seqd, cseqd, arcd|
        run_client client_class,
                   seq: seqd, cseq: cseqd, arc: arcd, log: log do |client|
          if block
            if block.arity == 0
              client.instance_eval &block
            else
              yield client
            end
          else
            client
          end
        end
      end
    end

    # Yields a client that runs in a subprocess.
    def child client_class = Client, &block
      ez.client :seqd, :cseqd, :arcd do |seqd, cseqd, arcd|
        run_client client_class,
                   seq: seqd, cseq: cseqd, arc: arcd, log: log do |client|
          if block
            if block.arity == 0
              client.instance_eval &block
            else
              yield client
            end
          else
            client
          end
        end
      end
    end

    def run_client client_class, opts
      log = opts[:log]
      log.progname = "client <starting in #{log.progname}>"
      client = client_class.new opts
      client.start do
        log.progname = "client #{client.client_id}"
      end
      yield client
    ensure
      client.stop if client # gracefully exit the tuplespace management thread
    end
  end

  #blob_type: 'msgpack' # the default
  #blob_type: 'marshal' # if you need to pass general ruby objects
  #blob_type: 'yaml' # less general ruby objects, but cross-language
  #blob_type: 'json' # more portable than yaml, but more restrictive

  def self.application argv: ARGV,
        servers_file: nil, blob_type: nil,
        seqd_addr: [], cseqd_addr: [], arcd_addr: [], &block

    log_level = case
      when argv.delete("--debug"); Logger::DEBUG
      when argv.delete("--info");  Logger::INFO
      when argv.delete("--warn");  Logger::WARN
      when argv.delete("--error"); Logger::ERROR
      when argv.delete("--fatal"); Logger::FATAL
      else Logger::WARN
    end

    unless blob_type
      %w{--marshal --yaml --json --msgpack}.each do |switch|
        s = argv.delete(switch) and
          blob_type ||= s.delete("--")
      end
      blob_type ||= "msgpack"
    end
    
    use_monitor = ARGV.delete("--monitor")

    svrs = servers_file || argv.shift || "servers-#$$.yaml"

    EasyServe.start(servers_file: svrs) do |ez|
      log = ez.log
      log.level = log_level
      log.progname = "parent"
      owns_servers = false

      ez.start_servers do
        owns_servers = true

        arc_to_seq_sock, seq_to_arc_sock = UNIXSocket.pair
        arc_to_cseq_sock, cseq_to_arc_sock = UNIXSocket.pair

        ez.server :seqd, *seqd_addr do |svr|
          require 'funl/message-sequencer'
          seq = Funl::MessageSequencer.new svr, seq_to_arc_sock, log: log,
            blob_type: blob_type
          seq.start
        end

        ez.server :cseqd, *cseqd_addr do |svr|
          require 'funl/client-sequencer'
          cseq = Funl::ClientSequencer.new svr, cseq_to_arc_sock, log: log
          cseq.start
        end

        ez.server :arcd, *arcd_addr do |svr|
          require 'tupelo/archiver'
          arc = Archiver.new svr, seq: arc_to_seq_sock,
            cseq: arc_to_cseq_sock, log: log
          arc.start
        end
      end

      app = AppBuilder.new(ez, owns_servers: owns_servers)
      
      if use_monitor
        require 'tupelo/app/monitor'
        app.start_monitor
      end

      if block
        if block.arity == 0
          app.instance_eval &block
        else
          yield app
        end
      else
        app
      end
    end
  end
end
