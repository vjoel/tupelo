require 'tupelo/archiver/tuplestore'

# Store for any kind of tuple, and faster for lookups of literal tuples,
# rather than matching with templates or other queries.
# See also example/multitier/kvstore.rb.
class HashStore < Tupelo::Archiver::TupleStore
  # Same as parent, but default the zero_tolerance to 1000.
  def initialize zero_tolerance: 1000
    super
  end

  def find_match_for template, distinct_from: []
    case template
    when Array, Hash # just a tuple
      super

    else
      # We added this case to Archiver::TupleStore just so the read(..)
      # will work correctly on tuples that are already in the store
      # when this process starts up. After that point, incoming tuples
      # are matched directly against the CRITICAL_EVENT template without
      # searching the store.

      # We're not going to use Client#take in this client, so there's no need
      # to handle the distinct_from keyword argument.
      raise "internal error" unless distinct_from.empty?

      find do |tuple|
        template === tuple
      end
    end
  end
end

