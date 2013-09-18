require 'sequel'

class Tupelo::PersistentArchiver
  class Tuplespace
    include Enumerable
    
    attr_reader :zero_tolerance

    def initialize(file: ":memory:",
                   zero_tolerance: Tupelo::Archiver::ZERO_TOLERANCE)
      @db = Sequel.sqlite(:database => file)
      @nzero = 0
      @zero_tolerance = zero_tolerance
    end
    
    # note: multiple equal tuples are yielded once
    def each
      @db[:tuples].select(:packed, :count).each do |row| ## select as array?
        packed, count = row.values_at(:packed, :count)
        yield packed, count if count > 0
      end
    end
    
    def insert packed
      if packed has exact match in data table
        inc count
      else
        let hash = packed_hash(str)
        select rows with this hash

        if op is insert
          if rows.count == 0, insert new row, with count=1
          else find row using packed_compare(str, packed_tuple)
            if found, increment count
            else insert new row, with count=1


      @db[:tuples].insert 
      @counts[tuple] += 1
    end
    
    def delete_once tuple
      if @counts[tuple] > 0
        @counts[tuple] -= 1
        if @counts[tuple] == 0
          @nzero += 1
          clear_excess_zeros if @nzero > zero_tolerance
        end
        true
      else
        false
      end
    end

    def transaction inserts: [], deletes: []
      deletes.each do |tuple|
        delete_once tuple or raise "bug"
      end

      inserts.each do |tuple|
        insert tuple.freeze ## freeze recursively
      end
    end

    def clear_excess_zeros
      nd = (@nzero - zero_tolerance / 2)
      @counts.delete_if {|tuple, count| count == 0 && (nd-=1) >= 0}
    end

    def find_distinct_matches_for tuples
      h = Hash.new(0)
      tuples.map do |tuple|
        if @counts[tuple] > h[tuple]
          h[tuple] += 1
          tuple
        else
          nil
        end
      end
    end

    def find_match_for tuple
      @counts[tuple] > 0 && tuple
    end
  end
end
