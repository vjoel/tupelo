require 'tupelo/app'

sv = "tiny-service.yaml"

Tupelo.application services_file: sv do
  if owns_services
    abort "service not running"
  end

  child do
    write ["Hello", "world!"]
    p take [nil, nil]
  end
end
