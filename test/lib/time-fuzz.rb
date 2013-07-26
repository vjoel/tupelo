module Tupelo
  module TimeFuzz
    DEFAULT_SLEEP_MAX = 0.01
    @sleep_max = DEFAULT_SLEEP_MAX

    class << self
      attr_accessor :sleep_max
    end

    module Api
      def trans_class
        TimeFuzz::Transaction
      end
    end

    class Transaction < Tupelo::Client::Transaction
      def worker_push event
        sleep sleep_duration
        super
      end

      def wait
        super
        sleep sleep_duration
      end

      def sleep_duration
        rand * TimeFuzz.sleep_max
      end
    end
    
    class Client < Tupelo::Client
      include TimeFuzz::Api
    end
  end
end
