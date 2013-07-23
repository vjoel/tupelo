require 'tupelo/client/reader'
require 'tupelo/client/transaction'

require 'mock-queue.rb'

class MockClient
  include Tupelo::Client::Api

  attr_accessor :worker
  attr_accessor :log
  attr_accessor :client_id
  attr_accessor :blobber
  attr_accessor :message_class
  attr_accessor :tuplespace
  attr_accessor :seq
  attr_accessor :arc
  attr_accessor :start_tick

  def updater
    @updater ||=
      Fiber.new do
        loop do
          log.debug "update begin"
          worker.update
          log.debug "update end"
          Fiber.yield
        end
      end
  end
  
  def update
    updater.resume
  end
  
  def make_queue
    MockQueue.new
  end
end
