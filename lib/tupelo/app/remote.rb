require 'tupelo/app'

module Tupelo
  class AppBuilder
    # Perform client operations on another host.
    #
    # There are two modes: drb and eval. In the drb mode, a block executes
    # locally, performing tuplespace operations by proxy to the remote
    # tupelo client instance. Results of the ops are available in the local
    # process. This is very useful for testing and examples.
    #
    # In the eval mode, a string is evaluated on the remote host in the context
    # of a client instance.
    #
    # There are some minor limitations compared to #child:
    #
    # In eval mode, the code string is always treated as in the arity 0 case
    # of #child, in other words "DSL mode", in other words the self is the
    # client.
    #
    # Unlike #child, there is no mode that returns a Client instance.
    #
    def remote client_class = Client,
        client_lib: 'tupelo/client', host: nil, **opts
      require 'easy-serve/remote'
      ## detach option so that remote process doesn't keep ssh connection
      snames = :seqd, :cseqd, :arcd

      if opts[:eval]
        ez.remote *snames, host: host, **opts, eval: %{
          require #{client_lib.inspect}

          seqd, cseqd, arcd = *conns
          client_class = Object.const_get(#{client_class.name.inspect})

          begin
            log.progname = "client <starting in \#{log.progname}>"
            client = client_class.new(
              seq: seqd, cseq: cseqd, arc: arcd, log: log)
            client.start do
              log.progname = "client \#{client.client_id}"
            end
            client.instance_eval #{opts[:eval].inspect}
          ensure
            client.stop if client
          end
        }

      elsif block_given?
        block = Proc.new
        ez.remote *snames, host: host, **opts do |seqd, cseqd, arcd|
          run_client client_class,
              seq: seqd, cseq: cseqd, arc: arcd, log: log do |client|
            if block.arity == 0
              client.instance_eval &block
            else
              yield client
            end
          end
        end

      else
        raise ArgumentError, "cannot select remote mode based on arguments"
      end
    end
  end
end
