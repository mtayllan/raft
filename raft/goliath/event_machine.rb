module Raft
  class Goliath
    class EventMachineAsyncProvider < Raft::AsyncProvider
      def await
        f = Fiber.current
        until yield
          EM.next_tick { f.resume }
          Fiber.yield
        end
      end
    end
  end
end
