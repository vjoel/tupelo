require 'easy-serve'
require 'tupelo/client'

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
    def local client_class = Client, **opts, &block
      ez.local :seqd, :cseqd, :arcd do |seqd, cseqd, arcd|
        opts = {seq: seqd, cseq: cseqd, arc: arcd, log: log}.merge(opts)
        run_client client_class, **opts do |client|
          if block
            if block.arity == 0
              client.instance_eval &block
            else
              yield client
            end
          end
        end
      end
    end

    # Yields a client that runs in a subprocess.
    #
    # A passive client will be forced to stop after all active clients exit. Use
    # the passive flag for processes that wait for tuples and respond in some
    # way. Then you do not have to manually interrupt the whole application when
    # the active processes are done. See examples.
    def child client_class = Client, passive: false, **opts, &block
      ez.child :seqd, :cseqd, :arcd, passive: passive do |seqd, cseqd, arcd|
        opts = {seq: seqd, cseq: cseqd, arc: arcd, log: log}.merge(opts)
        run_client client_class, **opts do |client|
          if block
            if block.arity == 0
              client.instance_eval &block
            else
              yield client
            end
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
  
  # Returns [argv, opts], leaving orig_argv unmodified. The opts hash contains
  # switches (and their arguments, if any) recognized by tupelo. The argv array
  # contains all unrecognized arguments.
  def self.parse_args orig_argv
    argv = orig_argv.dup
    opts = {}

    opts[:log_level] =
      case
      when argv.delete("--debug"); Logger::DEBUG
      when argv.delete("--info");  Logger::INFO
      when argv.delete("--warn");  Logger::WARN
      when argv.delete("--error"); Logger::ERROR
      when argv.delete("--fatal"); Logger::FATAL
      else Logger::WARN
      end

    opts[:verbose] = argv.delete("-v")

    if i = argv.index("--persist-dir")
      argv.delete_at(i)
      opts[:persist_dir] = argv.delete_at(i)
    end

    %w{--marshal --yaml --json --msgpack}.each do |switch|
      s = argv.delete(switch) and
        otps[:blob_type] = s.delete("--")
    end

    opts[:trace] = argv.delete("--trace")
    
    [argv, opts]
  end

  # same as application, but with tcp sockets the default
  def self.tcp_application argv: nil,
        servers_file: nil, blob_type: nil,
        seqd_addr:  [:tcp, nil, 0],
        cseqd_addr: [:tcp, nil, 0],
        arcd_addr:  [:tcp, nil, 0], **opts, &block
    application argv: argv, servers_file: servers_file, blob_type: blob_type,
      seqd_addr: seqd_addr, cseqd_addr: cseqd_addr, arcd_addr: arcd_addr, &block
  end

  #blob_type: 'msgpack' # the default
  #blob_type: 'marshal' # if you need to pass general ruby objects
  #blob_type: 'yaml' # less general ruby objects, but cross-language
  #blob_type: 'json' # more portable than yaml, but more restrictive

  def self.application argv: nil,
        servers_file: nil, blob_type: nil,
        seqd_addr: [], cseqd_addr: [], arcd_addr: [], **opts, &block
  
    unless argv
      argv, h = parse_args(ARGV)
      opts.merge! h
    end

    log_level = opts[:log_level]
    verbose = opts[:verbose]
    blob_type = blob_type || opts[:blob_type] || "msgpack" ## swap order?
    enable_trace = opts[:trace]
    persist_dir = opts[:persist_dir]

    ez_opts = {
      servers_file: servers_file || argv.shift,
      interactive: $stdin.isatty
    }

    EasyServe.start ez_opts do |ez|
      log = ez.log
      log.level = log_level
      log.formatter = nil if verbose
      log.progname = File.basename($0)
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
          if persist_dir
            require 'tupelo/archiver/persistent-tuplespace'
            arc = Archiver.new svr, seq: arc_to_seq_sock,
                    tuplespace: Archiver::PersistentTuplespace,
                    persist_dir: persist_dir,
                    cseq: arc_to_cseq_sock, log: log
          else
            arc = Archiver.new svr, seq: arc_to_seq_sock,
                    tuplespace: Archiver::Tuplespace,
                    cseq: arc_to_cseq_sock, log: log
          end
          arc.start
        end
      end

      app = AppBuilder.new(ez, owns_servers: owns_servers)
      
      if enable_trace
        require 'tupelo/app/trace'
        app.start_trace
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
