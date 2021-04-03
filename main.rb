require './raft/raft'
require './raft/goliath/goliath'

@goliaths = {}
@cluster = Raft::Cluster.new
@config = Raft::Config.new(
  Raft::Goliath.rpc_provider(proc { |node_id, message| URI("http://localhost:#{node_id}/#{message}") }),
  Raft::Goliath.async_provider,
  1.5, # election_timeout seconds
  1.0, # election_splay seconds
  0.2, # update_interval seconds
  1.0 # heartbeat_interval second
)

def create_node_on_port(port)
  @cluster.node_ids << port
  node = Raft::Node.new(port, @config, @cluster)
  @goliaths[port] = Raft::Goliath.new(node) { |command| puts "executing command #{command}" }
  @goliaths[port].start(port: port)
end

def consistent_logs?
  first_node = @goliaths.values.first.node
  puts "Log: #{first_node.persistent_state.log.map(&:command)}"

  @goliaths.values.map(&:node).all? do |node|
    cons = first_node.persistent_state.log == node.persistent_state.log
    cons &&= first_node.temporary_state.commit_index == node.temporary_state.commit_index
    cons && first_node.temporary_state.commit_index == first_node.persistent_state.log.last.index
  end
end

threads = [
  Thread.new { create_node_on_port('4000') },
  Thread.new { create_node_on_port('4001') },
  Thread.new { create_node_on_port('4002') },
  Thread.new do
    loop do
      p consistent_logs?
      sleep 3
    end
  end
]

threads.each(&:join)
