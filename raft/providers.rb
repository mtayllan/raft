module Raft
  class RpcProvider
    def request_votes(_request, _cluster)
      raise 'Your RpcProvider subclass must implement #request_votes'
    end

    def append_entries(_request, _cluster)
      raise 'Your RpcProvider subclass must implement #append_entries'
    end

    def append_entries_to_follower(_request, _node_id)
      raise 'Your RpcProvider subclass must implement #append_entries_to_follower'
    end

    def command(_request, _node_id)
      raise 'Your RpcProvider subclass must implement #command'
    end
  end

  class AsyncProvider
    def await
      raise 'Your AsyncProvider subclass must implement #await'
    end
  end
end
