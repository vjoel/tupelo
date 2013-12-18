require 'easy-serve'
require 'tupelo/client'
require 'tupelo/app/builder'

module Tupelo
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
        opts[:blob_type] = s.delete("--")
    end

    opts[:trace] = argv.delete("--trace")
    
    [argv, opts]
  end

  # same as application, but with tcp sockets the default
  def self.tcp_application argv: nil, services_file: nil, blob_type: nil,
        seqd_addr: {}, cseqd_addr: {}, arcd_addr: {}, **opts, &block
    seqd_addr[:proto] = cseqd_addr[:proto] = arcd_addr[:proto] = :tcp
    application argv: argv, services_file: services_file, blob_type: blob_type,
      seqd_addr: seqd_addr, cseqd_addr: cseqd_addr, arcd_addr: arcd_addr, &block
  end

  #blob_type: 'msgpack' # the default
  #blob_type: 'marshal' # if you need to pass general ruby objects
  #blob_type: 'yaml' # less general ruby objects, but cross-language
  #blob_type: 'json' # more portable than yaml, but more restrictive

  def self.application argv: nil,
        services_file: nil, blob_type: nil,
        seqd_addr: {}, cseqd_addr: {}, arcd_addr: {}, **opts, &block
  
    unless argv
      argv, h = parse_args(ARGV)
      opts.merge! h
    end

    log_level = opts[:log_level]
    verbose = opts[:verbose]
    blob_type = blob_type || "msgpack"
    enable_trace = opts[:trace]
    persist_dir = opts[:persist_dir]

    ez_opts = {
      services_file: services_file || argv.shift,
      interactive: $stdin.isatty
    }

    EasyServe.start ez_opts do |ez|
      log = ez.log
      log.level = log_level
      log.formatter = nil if verbose
      log.progname = File.basename($0)
      owns_services = false

      ez.start_services do
        owns_services = true

        arc_to_seq_sock, seq_to_arc_sock = UNIXSocket.pair
        arc_to_cseq_sock, cseq_to_arc_sock = UNIXSocket.pair

        ez.service :seqd, **seqd_addr do |sv|
          require 'funl/message-sequencer'
          seq = Funl::MessageSequencer.new sv, seq_to_arc_sock, log: log,
            blob_type: blob_type
          seq.start
        end

        ez.service :cseqd, **cseqd_addr do |sv|
          require 'funl/client-sequencer'
          cseq = Funl::ClientSequencer.new sv, cseq_to_arc_sock, log: log
          cseq.start
        end

        ez.service :arcd, **arcd_addr do |sv|
          require 'tupelo/archiver'
          if persist_dir
            require 'tupelo/archiver/persistent-tuplespace'
            arc = Archiver.new sv, seq: arc_to_seq_sock,
                    tuplespace: Archiver::PersistentTuplespace,
                    persist_dir: persist_dir,
                    cseq: arc_to_cseq_sock, log: log
          else
            arc = Archiver.new sv, seq: arc_to_seq_sock,
                    tuplespace: Archiver::Tuplespace,
                    cseq: arc_to_cseq_sock, log: log
          end
          arc.start
        end
      end

      app = AppBuilder.new(ez, owns_services: owns_services, argv: argv.dup)
      
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
