require 'tupelo/app'

Tupelo.application do
  child do
    ats = (0..4).map do |i|
      transaction.async do
        take ["start"]
        write [i]
      end
    end
    
    [0,1,2,4].each {|i| ats[i].cancel}

    write ["start"]
    p take [Integer]
  end
end
