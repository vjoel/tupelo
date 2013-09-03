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

  def update
    worker.update
  end
  
  def make_queue
    MockQueue.new
  end
end
