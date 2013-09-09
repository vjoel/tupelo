require 'tupelo/client'
require 'atdo'

module Tupelo
  class Client
    class AtDo < ::AtDo
      def initialize client, **opts
        @client = client
        super **opts
      end

      # Accepts numeric +time+. Logs errors in +action+. Otherwise, same
      # as ::AtDo.
      def at time, &action
        time = Time.at(time) if time.kind_of? Numeric
        super time do
          begin
            action.call
          rescue => ex
            @client.log.error "error in action scheduled for #{time}:" +
              " #{ex.class}: #{ex}\n  #{ex.backtrace.join("\n  ")}"
          end
        end
      end
    end
    
    def make_scheduler **opts
      AtDo.new self, **opts
    end
  end
end
