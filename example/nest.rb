require 'tupelo/app'

Tupelo.application do

  child do
    write [1]
    
    transaction timeout: 1 do |outer|
      x, _ = outer.read [1]
      
      transaction do
        write [x+1]
          # This is a programming error. The outer txn assumes that [1] exists.
          # The inner txn assumes that the outer txn executes. But in fact the
          # outer txn never executes (it times out), and the inner txn does
          # execute, leaving an unexpected [2] in the space.
      end
      
      outer.read ["barrier"]
    end
  end

  child do
    take [1]
    write ["barrier"]
  end
end
