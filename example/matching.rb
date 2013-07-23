require 'tupelo/app'

Tupelo.application do |app|
  app.local do |client|
    client.write_wait ["foo", 42.5]
    p client.read_all [/oo/, nil]
    p client.read_all [nil, 5..95]
  end
end
