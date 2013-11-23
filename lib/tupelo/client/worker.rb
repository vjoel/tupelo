require 'thread'
require 'tupelo/client/reader'
require 'tupelo/client/transaction'
require 'object-template'
require 'atdo'

class Tupelo::Client
  class Worker
    attr_reader :client
    attr_reader :seq
    attr_reader :arc
    attr_reader :client_id
    attr_reader :local_tick
    attr_reader :global_tick
    attr_reader :start_tick
    attr_reader :delta
    attr_reader :msg_reader_thread
    attr_reader :worker_thread
    attr_reader :cmd_queue
    attr_reader :tuplespace
    attr_reader :message_class
    attr_reader :blobber
    attr_reader :read_waiters
    attr_reader :prep_waiters
    attr_reader :trans_waiters
    attr_reader :notify_waiters
    attr_reader :subspaces

    GET_TUPLESPACE = "get tuplespace"

    class Operation
      attr_reader :atomic, :writes, :pulses, :takes, :reads
      ## "put" or "set" operation to ensure that at least one
      ## copy of a tuple exists?

      def initialize atomic, writes, pulses, takes, reads
        @atomic, @writes, @pulses, @takes, @reads =
          atomic, writes, pulses, takes, reads
      end
      
      NOOP = new([], [], [], [], [])

      def to_s
        ops = [ ["write", writes], ["pulse", pulses],
              ["take", takes], ["read", reads] ]
        ops.map! do |label, tuples|
          ["#{label} #{tuples.map(&:inspect).join(", ")}"] unless tuples.empty?
        end
        ops.compact!

        [atomic ? "atomic" : "batch", ops.join("; ")].join(" ")
      end
      alias inspect to_s
    end
    
    class Subspace
      attr_reader :tag
      
      def initialize metatuple, worker
        @metatuple = metatuple
        @tag = metatuple["tag"]

        spec = Marshal.load(Marshal.dump(metatuple["template"]))
        @pot = worker.pot_for(spec).optimize!
      end
      
      def === tuple
        @pot === tuple
      end
    end

    def initialize client
      @client = client
      @seq = nil
      @arc = nil
      @log = client.log

      @client_id = nil
      @global_tick = nil
      @start_tick = nil
      @local_tick = 0
      @delta = 0

      @cmd_queue = client.make_queue
      @tuplespace = nil
      @message_class = client.message_class
      @blobber = nil

      @read_waiters = []
      @prep_waiters = []
      @trans_waiters = []
      @notify_waiters = []
      @stopping = false
      @subspaces = []
    end

    def log *args
      if args.empty?
        @log
      else
        @log.unknown *args
      end
    end
    
    def tuplespace
      @tuplespace ||= begin
        if client.tuplespace.respond_to? :new
          client.tuplespace.new
        elsif client.tuplespace.class == Array # but not subclass of Array
          tsclass, *args = client.tuplespace
          tsclass.new(*args)
        else
          client.tuplespace
        end
      end
    end

    def start
      return if @worker_thread

      log.info "worker starting"
      observe_started_client

      @msg_reader_thread = Thread.new do
        run_msg_reader_thread
      end

      @worker_thread = Thread.new do
        run_worker_thread
      end
    end

    def in_thread?
      Thread.current == worker_thread
    end

    def observe_started_client
      @client_id = client.client_id
      @blobber = client.blobber
      @seq = client.seq
      @arc = client.arc
      @start_tick = client.start_tick
    end

    def stop
      cmd_queue << :stop
      worker_thread.join if worker_thread ## join(limit)?
      msg_reader_thread.kill if msg_reader_thread
      @atdo.stop if @atdo
    end

    # stop without any remote handshaking
    def stop!
      @msg_reader_thread.kill if msg_reader_thread
      @worker_thread.kill if worker_thread
      @atdo.stop if @atdo
    end

    def at time, &action
      @atdo ||= AtDo.new
      @atdo.at time do
        cmd_queue << action
      end
    end

    def << cmd
      cmd_queue << cmd
    end

    def run_msg_reader_thread
      read_messages_from_seq
      log.warn "connection to seq closed"
      handle_seq_closed
    rescue => ex
      log.error ex
      raise
    end

    def handle_seq_closed
      ## what to do here in general?
      ## for each waiter, push :stop into queue ?
    end

    def read_messages_from_seq
      seq.each do |msg|
        self << msg
      end
    end

    def run_worker_thread
      run_request_loop
    rescue => ex
      log.error ex
      raise
    end

    def run_request_loop
      catch :done do
        loop do
          handle_one_request
        end
      end
    end

    def handle_one_request
      case cmd = cmd_queue.pop
      when :stop
        @stopping = true
        if trans_waiters.empty?
          throw :done
        else
          log.info {"stopping; waiting for #{trans_waiters}"}
        end
      when message_class
        handle_message cmd
        if @stopping
          if trans_waiters.empty?
            throw :done
          else
            log.info {"stopping; waiting for #{trans_waiters}"}
          end
        end
      else
        handle_client_request cmd unless @stopping
      end
    end

    def update_to_tick tick: nil, tags: nil, all: false
      # At this point we know that the seq messages now accumulating in
      # cmd_queue are tick+1, tick+2, ....
      # (or a subset of this sequence if not subscribed_all).
      # Some of these might get discarded later if archiver is more current.
      log.debug {"update_to_tick #{tick}"}

      unless arc
        if tick > 0
          log.warn "no archiver provided; assuming pubsub mode; " +
            "some client ops (take and local read) will not work"
        end
        @global_tick = tick
        log.info "global_tick = #{global_tick}"
        return
      end

      log.info "requesting tuplespace from arc"
      subscription_delta = {
        request_all: all,
        request_tags: tags,
        subscribed_all: client.subscribed_all,
        subscribed_tags: client.subscribed_tags
      }
      arc << [GET_TUPLESPACE, subscription_delta, tick]

      begin
        tuplespace.clear
          ## in some cases, we can keep some of it, but the current
          ## archiver is not smart enough to send exactly the delta
          ### abort all current transactions???

        arc_tick = arc.read[0]
        log.info "arc says global_tick = #{arc_tick}"

        done = false
        count = 0
        arc.each do |tuple|
          if tuple.nil?
            done = true
          else
            raise "bad object stream from archiver" if done
            sniff_meta_tuple tuple
            tuplespace.insert tuple
            count += 1
          end
        end
        unless done
          raise "did not get all of tuplespace from archiver" ## roll back?
        end

        log.info "received tuplespace from arc: #{count} tuples"

        @global_tick = arc_tick
        log.info "global_tick = #{global_tick}"
      end

    ensure
      arc.close if arc and not arc.closed?
    end

    def handle_message msg
      log.debug {"seq sent #{msg.inspect}"}

      if msg.control?
        client.handle_ack msg
        op_type, tags = msg.control_op
        case op_type
        when Funl::SUBSCRIBE_ALL
          update_to_tick tick: msg.global_tick, all: true
        when Funl::SUBSCRIBE
          update_to_tick tick: msg.global_tick,
            tags: (client.subscribed_tags | tags)
        when Funl::UNSUBSCRIBE_ALL
          update_to_tick tick: msg.global_tick, all: false
        when Funl::UNSUBSCRIBE
          update_to_tick tick: msg.global_tick,
            tags: (client.subscribed_tags - tags)
        else
          raise "Unimplemented: #{msg.inspect}"
        end
        return
      end

      if !global_tick
        raise "bug: should have subscribed and received ack before data"
      end

      if msg.global_tick < global_tick + 1
        log.debug {"discarding redundant message at #{msg.global_tick}"}
          # due to archiver timing, for example
        return
      end

      @global_tick = msg.global_tick
      @delta = 0

      record_history msg
      op = msg.blob ? Operation.new(*blobber.load(msg.blob)) : Operation::NOOP
        ## op.freeze_deeply
      log.debug {"applying #{op} from client #{msg.client_id}"}

      notify_waiters.each do |waiter|
        waiter << [:attempt, msg.global_tick, msg.client_id, op]
      end

      granted_tuples = tuplespace.find_distinct_matches_for(op.takes)
      read_tuples = op.reads.map {|t| tuplespace.find_match_for(t)}

      succeeded = !op.atomic || (granted_tuples.all? && read_tuples.all?)
      actual_tuples = granted_tuples.compact

      if succeeded
        log.debug {"inserting #{op.writes}; deleting #{actual_tuples}"}
        tuplespace.transaction inserts: op.writes, deletes: actual_tuples,
          tick: @global_tick
      
        op.writes.each do |tuple|
          sniff_meta_tuple tuple
        end

        actual_tuples.each do |tuple|
          ### abstract this out
          if tuple.kind_of? Hash and tuple.key? "__tupelo__"
            if tuple["__tupelo__"] == "subspace" # tuple is subspace metatdata
              ## do some error checking
              subspaces.delete_if {|sp| sp.tag == tuple["tag"]}
            end
          end
        end
      end

      notify_waiters.each do |waiter|
        waiter << [
          succeeded ?  :success : :failure,
          msg.global_tick, msg.client_id, op]
      end

      trans = nil
      if msg.client_id == client_id
        trans = trans_waiters.first
        unless trans and trans.local_tick == msg.local_tick
          log.error "transaction #{op} out of order in sequence " +
            trans_waiters.inspect
          ## exit? wait?
        end
        trans_waiters.shift
        log.debug {"operation belongs to this client: #{trans.inspect}"}
      end

      if not actual_tuples.empty?
        if succeeded
          actual_tuples.each do |tuple|
            prep_waiters.keep_if do |waiter|
              waiter.unprepare tuple
              ## optimization: track number of instances of tuple, to avoid
              ## false positive in #unprepare
            end
          end

          log.debug {trans ? "taking #{granted_tuples}" :
            "client #{msg.client_id} takes #{granted_tuples}"}

        else
          log.debug {
            missing = op.takes - actual_tuples
            trans ? "failed to take #{missing}" :
            "client #{msg.client_id} failed to take #{missing}"}
        end
      end

      if succeeded
        op.writes.each do |tuple|
          read_waiters.delete_if do |waiter|
            waiter.gloms tuple
          end
        end

        op.pulses.each do |tuple|
          log.debug {"pulsing #{tuple}"}
          read_waiters.delete_if do |waiter|
            waiter.gloms tuple
          end
        end

        op.writes.each do |tuple|
          prep_waiters.keep_if do |waiter|
            waiter.prepare tuple
          end
        end
      end

      if trans
        trans_waiters.delete trans

        if succeeded
          trans.done msg.global_tick, granted_tuples # note: tuples not frozen
        else
          trans.fail (op.takes - actual_tuples) + (op.reads - read_tuples)
        end
      end
    end

    def sniff_meta_tuple tuple
      if tuple.kind_of? Hash and tuple.key? "__tupelo__"
        if tuple["__tupelo__"] == "subspace" # tuple is subspace metatdata
          ## do some error checking
          ## what if subspace already exists?
          subspaces << Subspace.new(tuple, self)
        end
      end
    end

    def record_history msg; end

    def handle_client_request req
      log.debug {"client requested #{req.inspect}"}

      case req
      when message_class
        raise "only seq can send messages"

      when Waiter
        handle_waiter req

      when Matcher
        handle_matcher req

      when Unwaiter
        handle_unwaiter req

      when Transaction
        handle_transaction req

      when NotifyWaiter
        notify_waiters.delete req or notify_waiters.push req

      when Proc
        req.call

      else
        raise "unknown request from client: #{req}"
      end
    rescue => ex
      log.error "error while handling #{req.inspect}: #{ex}"
      ## Raise an error in the waiter? Need to generalize the mechanism in
      ## Transaction.
    end

    def handle_transaction t
      case
      when t.open?
        t.prepare
        prep_waiters << t unless prep_waiters.include? t
      when t.closed?
        t.submit
        prep_waiters.delete t
      when t.failed?
      else
        log.warn "not open or closed or failed: #{t.inspect}"
      end
    rescue => ex
      log.error "error while handling #{t.inspect}: #{ex}"
      t.error ex
    end

    def handle_unwaiter unwaiter
      waiter = unwaiter.waiter
      read_waiters.delete waiter or prep_waiters.delete waiter
    end

    def handle_waiter waiter
      tuple = tuplespace.find_match_for waiter.template
      if tuple
        waiter.peek tuple
      else
        read_waiters << waiter
      end
    end

    def handle_matcher matcher
      if matcher.all
        tuplespace.each {|tuple| matcher.gloms tuple}
          ## maybe should have tuplespace.find_all_matches_for ...
          ## in case there is an optimization
        matcher.fails
      else
        tuple = tuplespace.find_match_for waiter.template
        if tuple
          waiter.peek tuple
        else
          matcher.fails
        end
      end
    end

    def send_transaction transaction
      msg = message_class.new
      msg.client_id = client_id
      msg.local_tick = local_tick + 1
      msg.global_tick = global_tick
      msg.delta = delta + 1 # pipelined write/take
      msg.tags = transaction.tags

      writes = transaction.writes
      pulses = transaction.pulses
      takes = transaction.take_tuples_for_remote.compact
      reads = transaction.read_tuples_for_remote.compact
      
      unless msg.tags
        tags = []
        tuples = [writes, pulses, takes, reads].compact.flatten(1)
        subspaces.each do |subspace|
          tuples.each do |tuple|
            if subspace === tuple
              tags << subspace.tag
              break
            end
          end
        end

        will_get_this_msg = client.subscribed_all ||
          tags.any? {|tag| client.subscribed_tags.include? tag} ## optimize

        unless will_get_this_msg
          tags << true # reflect
        end

        if not tags.empty?
          msg.tags = tags
          log.debug {"tagged transaction: #{tags}"}
        end
      end

      begin
        msg.blob = blobber.dump([
          transaction.atomic,
          writes, pulses, takes, reads
        ])
        ## optimization: use bitfields to identify which ops are present
        ## (instead of nils), and combine this with atomic flag in one int
      rescue => ex
        raise ex, "cannot serialize #{transaction.inspect}: #{ex}"
      end

      begin
        seq << msg
      rescue => ex
        raise ex, "cannot send request for #{transaction.inspect}: #{ex}"
      end

      @local_tick += 1
      @delta += 1

      trans_waiters << transaction

      return msg.local_tick
    end

    # Used by api to protect worker's copy from client changes.
    # Also, for serialization types that don't represent symbols,
    # this converts a template so that it works correctly regardless.
    # So keyword args are very natural: read(k1: val, k2: val)
    def make_template obj
      return obj unless obj.respond_to? :to_ary or obj.respond_to? :to_hash
      spec = Marshal.load(Marshal.dump(obj))
      rot_for(spec).optimize!
    end

    def rot_for spec
      RubyObjectTemplate.new(spec, proc {|k| blobber.load(blobber.dump(k))})
    end

    def pot_for spec
      PortableObjectTemplate.new(spec, proc {|k| blobber.load(blobber.dump(k))})
    end
  end
end
