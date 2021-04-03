module Raft
  class PersistentState
    attr_reader :current_term, :voted_for, :log

    def initialize
      @current_term = 0
      @voted_for = nil
      @log = Log.new([])
    end

    def current_term=(new_term)
      raise 'cannot restart an old term' unless @current_term < new_term

      @current_term = new_term
      @voted_for = nil
    end

    def voted_for=(new_votee)
      raise 'cannot change vote for this term' unless @voted_for.nil?

      @voted_for = new_votee
    end

    def log=(new_log)
      @log = Log.new(new_log)
    end
  end

  class TemporaryState
    attr_reader :commit_index
    attr_accessor :leader_id

    def initialize(commit_index, leader_id)
      @commit_index = commit_index
      @leader_id = leader_id
    end

    def commit_index=(new_commit_index)
      raise 'cannot uncommit log entries' unless @commit_index.nil? || @commit_index <= new_commit_index

      @commit_index = new_commit_index
    end
  end

  class LeadershipState
    def followers
      @followers ||= {}
    end

    attr_reader :update_timer

    def initialize(update_interval)
      @update_timer = Timer.new(update_interval)
    end
  end
end
