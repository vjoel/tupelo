# The shop has products, customers, and shopping carts. Customers move
# products to their carts, and the app has to prevent two customers getting
# the same instance of a product.
#
# It works, but every process has to handle every transaction. Not good. See
# shop-v2.rb.

require 'tupelo/app'

PRODUCT_IDS = 1..10
CUSTOMER_IDS = 1..10

Tupelo.application do
  local do
    PRODUCT_IDS.each do |product_id|
      count = 10
      write ["product", product_id, count]
    end
  end
  
  CUSTOMER_IDS.each do |customer_id|
    child passive: true do
      loop do
        sleep rand % 0.1
        transaction do
          # buy the first product we see:
          _, product_id, count = take ["product", nil, 1..Float::INFINITY]
          write ["product", product_id, count-1]
          write ["cart", customer_id, product_id]
        end
      end
    end
  end
  
  local do
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
