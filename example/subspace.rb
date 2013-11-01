require 'tupelo/app'

Tupelo.application do
  local do
    log [subscribed_all, subscribed_tags]

    use_subspaces!

    define_subspace(
      tag:          "foo",
      template:     [
        {type: "number"}
      ]
    )

    write_wait [0]

    log read_all(Object)
  end
  
  cid = child subscribe: ["foo"] do
    log [subscribed_all, subscribed_tags]
    write [1]
    write_wait ["abc"]
    log read_all(Object)
  end
  Process.wait cid

  local do
    log [subscribed_all, subscribed_tags]
    log read_all(Object)
    log read_all(subspace "foo")
  end
end
