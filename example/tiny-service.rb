require 'tupelo/app'

sv = "tiny-service.yaml"

Tupelo.application services_file: sv do
  if owns_services
    puts "service started"
    sleep
  else
    abort "service seems to be running already; check file #{sv.inspect}"
  end
end
