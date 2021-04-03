module Raft
  class Cluster
    attr_reader :node_ids

    def initialize(*node_ids)
      @node_ids = node_ids
    end

    def quorum
      @node_ids.count / 2 + 1 # integer division rounds down
    end
  end
end
