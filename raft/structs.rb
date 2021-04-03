module Raft
  Config = Struct.new(:rpc_provider, :async_provider, :election_timeout, :election_splay, :update_interval, :heartbeat_interval)

  FollowerState = Struct.new(:next_index, :succeeded)

  RequestVoteRequest = Struct.new(:term, :candidate_id, :last_log_index, :last_log_term)

  RequestVoteResponse = Struct.new(:term, :vote_granted)

  AppendEntriesRequest = Struct.new(:term, :leader_id, :prev_log_index, :prev_log_term, :entries, :commit_index)

  AppendEntriesResponse = Struct.new(:term, :success)

  CommandRequest = Struct.new(:command)

  CommandResponse = Struct.new(:success)
end
