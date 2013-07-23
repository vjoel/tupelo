require 'tupelo/app'

Tupelo.application do |app|
  app.child do |client|
    client.write ['x', 1]
    client.write ['y', 2]
  end
  
  app.child do |client|
    sum =
      client.transaction do |t|
        _, x = t.take ['x', Numeric]
        _, y = t.take ['y', Numeric]
        x + y
      end
    
    client.log "sum = #{sum}"
  end
end
