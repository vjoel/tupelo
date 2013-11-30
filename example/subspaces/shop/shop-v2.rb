# Makes the shop a bit more efficient using subspaces. Each customer needs to
# subscribe only to the inventory tuples, not to all the tuples in customer
# carts. Run with --trace to see tuples assigned to subspaces and also note how
# much contention there is.

require 'tupelo/app'

PRODUCT_IDS = 1..10
CUSTOMER_IDS = 1..10

Tupelo.application do
  local do
    use_subspaces!

    define_subspace(
      tag:          "inventory",
      template:     [
        {value: "product"},
        nil,                  # product_id
        {type:  "number"}     # count
      ]
    )

    PRODUCT_IDS.each do |product_id|
      count = 10
      write ["product", product_id, count]
    end
  end

  CUSTOMER_IDS.each do |customer_id|
    child subscribe: "inventory", passive: true do
      loop do
        sleep rand % 0.1
        transaction do
          # buy the first product we see:
          _, product_id, count = take ["product", nil, 1..Float::INFINITY]
          write ["product", product_id, count-1]
          write ["cart", customer_id, product_id]
          # Note that the transaction *takes* from inventory and *writes*
          # outside inventory. To support this, the client must subscribe
          # to inventory. It doesn't matter whether it subscribes to the
          # rest of the tuplespace. See the [subspace doc](doc/subspace.md).
        end
      end
    end
  end
  
  local subscribe: :all do
    PRODUCT_IDS.each do |product_id|
      read ["product", product_id, 0] # wait until sold out
    end
    
    CUSTOMER_IDS.each do |customer_id|
      h = Hash.new(0)
      transaction do
        while t=take_nowait(["cart", customer_id, nil])
          h[t[2]] += 1
        end
      end
      puts "Customer #{customer_id} bought:"
      h.keys.sort.each do |product_id|
        printf "%10d of product %3d.\n", h[product_id], product_id
      end
    end
  end
end
