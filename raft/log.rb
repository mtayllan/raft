module Raft
  class Log < DelegateClass(Array)
    def last(*args)
      self.any? ? super(*args) : LogEntry.new(nil, nil, nil)
    end
  end
end

