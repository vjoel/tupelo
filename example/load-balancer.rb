require 'tupelo/app'

N_WORKERS = 10
N_CLIENTS = 2

Tupelo.application do
  
  N_WORKERS.times do |i|
    child passive: true do
      log.progname = "worker #{i}"
      worker_delay = rand 1.0..5.0 # how long it takes this worker to do a task

      loop do
        _, req_id, req_dat = take ["request", Integer, nil]
        log.info "handling request #{req_id} for #{req_dat.inspect}"
        write ["response", req_id]
        sleep worker_delay
        log.info "handled request #{req_id} for #{req_dat.inspect}"
      end
    end
  end
  
  N_CLIENTS.times do |i|
    child do
      log.progname = "client #{i}"

      req_data = 1..20 # task spec here
      
      req_data.each do |req_dat|
        req_id = nil
        transaction do
          _, req_id = take ["next_req_id", Integer]
          write ["next_req_id", req_id + 1]
          write ["request", req_id, req_dat]
        end

        take ["response", req_id]
        log "got response for #{req_id}"
      end
    end
  end
  
  local do
    write ["next_req_id", 0]
  end
end
