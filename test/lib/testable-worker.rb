require 'tupelo/client/worker'
require 'tupelo/client/tuplespace'

class TestableWorker < Tupelo::Client::Worker
  def initialize client
    super
    
    @cmd_queue = MockQueue.new
    
    observe_started_client
    update_to_tick tick: 0
  end

  def in_thread?
    true
  end
  
  def update
    begin
      handle_one_request unless cmd_queue.empty?
      read_messages_from_seq # doesn't block; reads from seq to queue
    end until cmd_queue.empty?
  end
end
