# See tiny-tcp-service.rb

require 'tupelo/app'

Tupelo.application do
  if owns_services
    abort "service not running"
  end

  local do
    x = rand(0..100); y = rand(0..100)
    write [x, y]
    log "%p + %p = %p" % take([x, y, Numeric])
  end
end
