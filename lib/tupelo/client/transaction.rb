require 'tupelo/client/common'
require 'timeout' # just for TimeoutError

class Tupelo::Client
  class TransactionError < StandardError; end
  class TransactionStateError < TransactionError; end
  class TransactionAbort < TransactionError; end
  class TransactionFailure < TransactionError; end

  module Api
    # Transactions are atomic by default, and are always isolated. In the
    # non-atomic case, a "transaction" is really a batch op. Without a block,
    # returns the Transaction. In the block form, transaction automatically
    # waits for successful completion and returns the value of the block.
    def transaction atomic: true, timeout: nil
      deadline = timeout && Time.now + timeout
      begin
        t = Transaction.new self, atomic: atomic, deadline: deadline
        return t unless block_given?
        val = yield t
        t.commit.wait
        return val
      rescue TransactionFailure => ex
        log.info {"retrying #{t.inspect}: #{ex}"}
        retry
      rescue TransactionAbort
        log.info {"aborting #{t.inspect}"}
      end
    end
    
    def batch &bl
      transaction atomic: false, &bl
    end
    
    def abort
      raise TransactionAbort
    end

    # returns an object whose #wait method waits for write to be ack-ed
    def write_nowait *tuples
      t = transaction atomic: false
      t.write *tuples
      t.commit
    end
    alias write write_nowait

    # waits for write to be ack-ed
    def write_wait *tuples
      write_nowait(*tuples).wait
    end

    def pulse_nowait *tuples
      t = transaction atomic: false
      t.pulse *tuples
      t.commit
    end
    alias pulse pulse_nowait

    def pulse_wait *tuples
      pulse_nowait(*tuples).wait
    end

    def take template, timeout: nil
      transaction timeout: timeout do |t|
        tuple = t.take template
        yield tuple if block_given?
        tuple
      end
    end

    def take_nowait template
      transaction do |t|
        tuple = t.take_nowait template
        return nil if tuple.nil?
        yield tuple if block_given?
        tuple
      end
    end
  end
  
  class Transaction
    attr_reader :client
    attr_reader :worker
    attr_reader :log
    attr_reader :atomic
    attr_reader :deadline
    attr_reader :status
    attr_reader :global_tick
    attr_reader :local_tick
    attr_reader :exception
    attr_reader :writes
    attr_reader :pulses
    attr_reader :take_templates
    attr_reader :read_templates
    attr_reader :take_tuples
    attr_reader :read_tuples
    attr_reader :granted_tuples
    attr_reader :missing
    
    STATES = [
      OPEN      = :open,    # initial state
      CLOSED    = :closed,  # client thread changes open -> closed
                            # after closed, client cannot touch any state
      PENDING   = :pending, # worker thread changes closed -> pending | failed
      DONE      = :done,    # worker thread changes pending -> done (terminal)
      FAILED    = :failed   # worker thread changes pending -> failed (terminal)
    ]
    
    STATES.each do |s|
      class_eval %{
        def #{s}?; @status == #{s.inspect}; end
        def #{s}!; @status = #{s.inspect}; end
        private :#{s}!
      }
    end

    def initialize client, atomic: true, deadline: nil
      @client = client
      @worker = client.worker
      @log = client.log
      @atomic = atomic
      @deadline = deadline
      @global_tick = nil
      @exception = nil
      @local_tick = nil
      @queue = client.make_queue
      @mutex = Mutex.new
      @writes = []
      @pulses = []
      @take_templates = []
      @read_templates = []
      @take_tuples = []
      @read_tuples = []
      @granted_tuples = nil
      @missing = nil
      @_take_nowait = nil
      
      if deadline
        worker.at deadline do
          cancel(TimeoutError) if open?
        end
      end
      
      open!
    end
    
    def inspect
      stat_extra =
        case
        when pending?
          "at local_tick: #{local_tick}"
        when done?
          "at global_tick: #{global_tick}"
        end
      
      stat = [status, stat_extra].compact.join(" ")
      
      ops = [ ["write", writes], ["pulse", pulses],
            ["take", take_templates], ["read", read_templates] ]
      ops.map! do |label, tuples|
        ["#{label} #{tuples.map(&:inspect).join(", ")}"] unless tuples.empty?
      end
      ops.compact!
      
      b = atomic ? "atomic" : "batch"
      ops << "missing: #{missing}" if missing

      ## show take/read tuples too?
      ## show current tick, if open or closed
      ## show nowait
      
      "<#{self.class} #{stat} #{b} #{ops.join('; ')}>"
    end
    
    # :section: Client methods

    def check_tuples tuples
      tuples.each do |tuple|
        tuple.respond_to?(:size) and tuple.respond_to?(:fetch) or
          raise ArgumentError, "Not a tuple: #{tuple.inspect}"
      end
    end

    def write *tuples
      raise TransactionStateError, "not open: #{inspect}" unless open? or
        failed?
      check_tuples tuples
      @writes.concat tuples
      nil
    end
    
    def pulse *tuples
      raise exception if failed?
      raise TransactionStateError, "not open: #{inspect}" unless open? or
        failed?
      check_tuples tuples
      @pulses.concat tuples
      nil
    end
    
    # raises TransactionFailure
    def take template_spec
      raise "cannot take in batch" unless atomic
      raise exception if failed?
      raise TransactionStateError, "not open: #{inspect}" unless open? or
        failed?
      template = worker.make_template(template_spec)
      @take_templates << template
      log.debug {"asking worker to take #{template_spec.inspect}"}
      worker << self
      wait
      return take_tuples.last
    end
    
    def take_nowait template_spec
      raise "cannot take in batch" unless atomic
      raise exception if failed?
      raise TransactionStateError, "not open: #{inspect}" unless open? or
        failed?
      template = worker.make_template(template_spec)
      @_take_nowait ||= {}
      i = @take_templates.size
      @_take_nowait[i] = true
      @take_templates << template
      log.debug {"asking worker to take_nowait #{template_spec.inspect}"}
      worker << self
      wait
      return take_tuples[i]
    end
    
    # transaction applies only if template has a match
    def read template_spec
      raise "cannot read in batch" unless atomic
      raise exception if failed?
      raise TransactionStateError, "not open: #{inspect}" unless open? or
        failed?
      template = worker.make_template(template_spec)
      @read_templates << template
      log.debug {"asking worker to read #{template_spec.inspect}"}
      worker << self
      wait
      return read_tuples.last
    end
    
    # idempotent
    def commit
      if open?
        closed!
        log.info {"committing #{inspect}"}
        worker << self
      else
        raise exception if failed?
      end
      return self
    end
    
    def wait
      return self if done?
      raise exception if failed?
      
      log.debug {"waiting for #{inspect}"}
      @queue.pop
      log.debug {"finished waiting for #{inspect}"}

      return self if done? or open?
      raise exception if failed?
      log.error inspect
      raise "bug: #{inspect}"

    rescue TransactionAbort, Interrupt, TimeoutError => ex ## others?
      worker << Unwaiter.new(self)
      raise ex.class,
        "#{ex.message}: client #{client.client_id} waiting for #{inspect}"
    end

    def value
      wait
      granted_tuples
    end
    
    class TransactionThread < Thread
      def initialize t, *args
        super(*args)
        @transaction = t
      end
      def cancel
        @transaction.cancel
      end
    end

    def async
      raise ArgumentError, "must provide block" unless block_given?
      TransactionThread.new(self) do ## Fiber?
        begin
          val = yield self
          commit.wait
          val
        rescue TransactionFailure => ex
          log.info {"retrying #{t.inspect}: #{ex}"}
          retry
        rescue TransactionAbort
          log.info {"aborting #{t.inspect}"}
        end
      end
    end

    # :section: Worker methods
    
    def in_worker_thread?
      worker.in_thread?
    end

    def prepare new_tuple = nil
      return false if closed? or failed? # might change during this method
      raise unless in_worker_thread?

      if new_tuple
        return true if take_tuples.all? and read_tuples.all?

        take_tuples.each_with_index do |tuple, i|
          if not tuple and take_templates[i] === new_tuple
            take_tuples[i] = new_tuple
            log.debug {"prepared #{inspect} with #{new_tuple}"}
            break
          end
        end

        read_tuples.each_with_index do |tuple, i|
          if not tuple and read_templates[i] === new_tuple
            read_tuples[i] = new_tuple
            log.debug {"prepared #{inspect} with #{new_tuple}"}
          end
        end

      else
        ## optimization: use tuple cache
        skip = nil
        (take_tuples.size...take_templates.size).each do |i|
          take_tuples[i] = worker.tuplespace.find_match_for(
            take_templates[i], distinct_from: take_tuples)
          if take_tuples[i]
            log.debug {"prepared #{inspect} with #{take_tuples[i]}"}
          else
            if @_take_nowait and @_take_nowait[i]
              (skip ||= []) << i
            end
          end
        end

        skip and skip.reverse_each do |i|
          take_tuples.delete_at i
          take_templates.delete_at i
          @_take_nowait.delete i
        end
        
        (read_tuples.size...read_templates.size).each do |i|
          read_tuples[i] = worker.tuplespace.find_match_for(
            read_templates[i])
          if read_tuples[i]
            log.debug {"prepared #{inspect} with #{read_tuples[i]}"}
          end
        end
      end
      
      ## convert cancelling write/take to pulse
      ## convert cancelling take/write to read
      ## check that remaining take/read tuples do not cross a space boundary
      
      if take_tuples.all? and read_tuples.all?
        @queue << true
        log.debug {
          "prepared #{inspect}, " +
          "take tuples: #{take_tuples}, read tuples: #{read_tuples}"}
      end
      
      return true
    end

    def unprepare missing_tuple
      return false if closed? or failed? # might change during this method
      raise unless in_worker_thread?

      @take_tuples.each do |tuple|
        if tuple == missing_tuple ## might be false positive, but ok
          fail [missing_tuple]
            ## optimization: manage tuple cache
          return false
        end
      end

      @read_tuples.each do |tuple|
        if tuple == missing_tuple ## might be false positive, but ok
          fail [missing_tuple]
          return false
        end
      end

      ## redo the conversions etc
      return true
    end
    
    def submit
      raise TransactionStateError, "must be closed" unless closed?
      raise unless in_worker_thread?

      @local_tick = worker.send_transaction self
      pending!
    end
    
    def done global_tick, granted_tuples
      raise TransactionStateError, "must be pending" unless pending?
      raise unless in_worker_thread?
      raise if @global_tick or @exception

      @global_tick = global_tick
      done!
      @granted_tuples = granted_tuples
      log.info {"done with #{inspect}"}
      @queue << true
    end

    def fail missing
      raise unless in_worker_thread?
      raise if @global_tick or @exception
      
      @missing = missing
      @exception = TransactionFailure
      failed!
      @queue << false
    end
    
    def error ex
      raise unless in_worker_thread?
      raise if @global_tick or @exception
      
      @exception = ex
      failed!
      @queue << false
    end

    # Called by another thread to cancel a waiting transaction.
    def cancel err = TransactionAbort
      worker << proc do
        raise unless in_worker_thread?
        if @global_tick or @exception
          log.info {"cancel was applied too late: #{inspect}"}
        else
          @exception = err.new
          failed!
          @queue << false
        end
      end
    end
  end
end
