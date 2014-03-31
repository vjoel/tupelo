require_relative 'ordered-event-store'

class Tupelo::Client
  # Expire old events.
  #
  # A little more complex than v1, but more efficient.
  #
  # This version uses the rbtree to manage the tuplestore itself (in the worker
  # thread), instead of using an rbtree to manage the scheduler (in the client
  # thread). It also uses a custom template class to perform range-based queries
  # of the rbtree key, which is not explicitly stored in the tuples. The rbree
  # key is, however, the sum of two values (time + ttl) in the tuples, so the
  # template is still selecting tuples based on their contents.
  #
  def run_expirer_v2
    loop do
      event = read subspace("event") # event with lowest time+ttl
        # This just happens to be true, but alternately we could define
        # OrderedEventTemplate.first() to make a template that explicitly
        # finds the lowest key.
      dt_next_expiration = event["time"] + event["ttl"] - Time.now.to_f
      begin
        transaction timeout: dt_next_expiration do
          read OrderedEventTemplate.before(event)
        end
      rescue TimeoutError
        transaction do
          take_nowait event or break # see note in v1/expirer.rb
          pulse event.merge("state" => "expired")
        end
      end
    end
  end
end
