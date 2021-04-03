module Raft
  class Timer
    def initialize(interval, splay = 0.0)
      @interval = interval.to_f
      @splay = splay.to_f
      @start = Time.now - @interval + (rand * @splay)
    end

    def splayed_interval
      (@interval + (rand * @splay)) # .tap {|t|# print("\nsplayed interval is #{t}\n")}
    end

    def reset!
      @start = Time.now + splayed_interval
      # print("\ntimer will elapse at #{timeout.strftime('%H:%M:%S:%L')} (timeout is #{timeout.class})\n")
    end

    def timeout
      @start + @interval
    end

    def timed_out?
      # print("\ntime is #{Time.now.strftime('%M:%S:%L')}\n")
      Time.now > timeout
    end
  end
end
