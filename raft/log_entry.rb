module Raft
  class LogEntry
    attr_reader :term, :index, :command

    def initialize(term, index, command)
      @term = term
      @index = index
      @command = command
    end

    def ==(other)
      %i[term index command].all? do |attr|
        send(attr) == other.send(attr)
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      %i[term index command].reduce(0) do |h, attr|
        h ^= send(attr)
      end
    end
  end
end
