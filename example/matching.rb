require 'tupelo/app'

Tupelo.application do
  local do
    write_wait ["foo", 42.5]
    p read_all [/oo/, nil]
    p read_all [nil, 5..95]
  end
end
