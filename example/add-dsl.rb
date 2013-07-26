# A little ruby magic to sweeten the syntax. Compare add.rb
#
# The old syntax is still accepted. Switching between syntaxes is caused by the
# presence of the '|...|' form. When present, it's important to keep in mind
# that 'self' and instance vars inside the block are not the same as outside the
# block. In other respects, such as local vars, these closures behave normally.
# This is ruby's famous instance_eval gotcha.

require 'tupelo/app/dsl'

Tupelo::DSL.application do
  child do
    write ['x', 1]
    write ['y', 2]
  end
  
  child do
    sum =
      transaction do
        _, x = take ['x', Numeric]
        _, y = take ['y', Numeric]
        x + y
      end
    
    log "sum = #{sum}"
  end
end
