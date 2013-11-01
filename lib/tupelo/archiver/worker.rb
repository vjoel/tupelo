require 'funl/history-worker'

class Tupelo::Archiver
  class Worker < Tupelo::Client::Worker
    include Funl::HistoryWorker
    
    def initialize *args, **opts
      super *args
      @scheduled_actions = Hash.new {|h,k| h[k] = []}
      @opts = opts
    end

    def tuplespace
      @tuplespace ||= begin
        if client.tuplespace.respond_to? :new
          client.tuplespace.new **@opts
        else
          client.tuplespace
        end
      end
    end

    def stop
      super
      tuplespace.flush global_tick
    end

    def handle_client_request req
      case req
      when Tupelo::Archiver::ForkRequest
        handle_fork_request req
      else
        super
      end
    end

    def handle_fork_request req
      stream = client.arc_server_stream_for req.io

      begin
        op, sub_delta, tick = stream.read
      rescue EOFError
        log.debug {"#{stream.peer_name} disconnected from archiver"}
        return
      rescue => ex
        log.error "in fork for #{stream || req.io}: #{ex.inspect}"
      end

      log.info {
        "#{stream.peer_name} requested #{op.inspect} at tick=#{tick}" +
          (sub_delta ? " for #{sub_delta}" : "")}

      if tick <= global_tick
        fork_for_op op, sub_delta, tick, stream, req
      else
        at_tick tick do
          fork_for_op op, sub_delta, tick, stream, req
        end
      end
    end

    def fork_for_op op, sub_delta, tick, stream, req
      fork do
        begin
          case op
          when "new client"
            raise "Unimplemented" ###
          when "get range" ### handle this in Funl::HistoryWorker
            raise "Unimplemented" ###
          when GET_TUPLESPACE
            send_tuplespace stream, sub_delta
          else
            raise "Unknown operation: #{op.inspect}"
          end
        rescue EOFError
          log.debug {"#{stream.peer_name} disconnected from archiver"}
        rescue => ex
          log.error "in fork for #{stream || req.io}: #{ex.inspect}"
        end
      end
    ensure
      req.io.close
    end
    
    def at_tick tick, &action
      @scheduled_actions[tick] << action
    end

    def handle_message msg
      super
      actions = @scheduled_actions.delete(global_tick)
      actions and actions.each do |action|
        action.call
      end
    end

    def send_tuplespace stream, sub_delta
      log.info {
        "send_tuplespace to #{stream.peer_name} " +
        "at tick #{global_tick.inspect} " +
        (sub_delta ? " with sub_delta #{sub_delta.inspect}" : "")}
      
      stream << [global_tick]

      ## better: make use of sub_delta["subscribed_*"] to reduce what
      ## has to be sent.

      if sub_delta["request_all"]
        tuplespace.each do |tuple, count|
          count.times do ## just dump and send str * count?
            stream << tuple ## optimize this, and cache the serial
            ## optimization: use stream.write_to_buffer
          end
        end

      else
        tags = sub_delta["request_tags"] ## use set
        subs = subspaces.select {|sub| tags.include? sub.tag}

        tuplespace.each do |tuple, count|
          ## alternately, store tags with tuples (risk if dynamic spaces)
          if subs.any? {|sub| sub === tuple}
            count.times do
              stream << tuple
              ## optimization: use stream.write_to_buffer
            end
          end
          ## optimize this if templates have simple form, such as
          ##   [ [str1, nil, ...], [str2, nil, ...], ...]
        end
      end

      stream << nil # terminator
      ## stream.flush or close if write_to_buffer used above
    end
  end
end
