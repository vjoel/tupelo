require 'tupelo/app'

Tupelo.application do
  expected = [[1], [2], [3]]

  local do
    write *expected
  end
      
  child_pid = child do
    # Test that tuples written before this client started are readable.
    a = read_all [Integer]
    write_wait result: a
  end

  # Normally we would wait using tuples, but in this case we want more
  # isolation in the test case, so we wait in terms of the PID.
  Process.waitpid child_pid

  local do
    h = read_all result: Array
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
