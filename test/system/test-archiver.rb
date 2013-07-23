require 'tupelo/app'

Tupelo.application do |app|
  expected = [[1], [2], [3]]

  app.local do |client|
    client.write *expected
  end
      
  child_pid = app.child do |client|
    # Test that tuples written before this client started are readable.
    a = client.read_all [Integer]
    client.write result: a
    sleep 0.1
  end

  # Normally we would wait using tuples, but in this case we want more
  # isolation in the test case, so we wait in terms of the PID.
  Process.waitpid child_pid

  app.local do |client|
    h = client.read_all result: Array
    begin
      a = h.first["result"]
    rescue => ex
      abort "FAIL: #{ex}, h=#{h.inspect}"
    end

    if a == expected
      puts "OK"
    else
      abort "FAIL: a=#{a.inspect}, expected=#{expected.inspect}"
    end
  end
end
