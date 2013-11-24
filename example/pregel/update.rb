def update vertex, incoming_messages, vs_dst
  vertex = vertex.dup
  incoming_messages ||= []
  outgoing_messages = []
  v_me = vertex["id"]
  rank = vertex["rank"]
  step = vertex["step"]
  active = true

  if step < 50
    rank = 0.15 / NUM_VERTICES + 0.85 * incoming_messages.inject(0.0) {|sum, m|
      sum + m["rank"]}
    outgoing_rank = rank / vs_dst.size
    outgoing_messages = vs_dst.map {|v_dst|
      {src: v_me, dst: v_dst, step: step + 1, rank: outgoing_rank}}
  else
    active = false
  end

  vertex["rank"] = rank
  vertex["active"] = active
  vertex["step"] += 1

  [vertex, outgoing_messages]
end
