module Tupelo
  class Client
    class Unwaiter
      attr_reader :waiter
      def initialize waiter
        @waiter = waiter
      end
    end
  end
end
