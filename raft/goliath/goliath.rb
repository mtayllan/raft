require 'goliath'
require 'em-http-request'

require_relative './http_rpc'
require_relative './event_machine'

module Raft
  class Goliath
    def self.log(message)
      print("\n\n")
      print(message)
      print("\n\n")
    end

    def self.rpc_provider(uri_generator)
      HttpJsonRpcProvider.new(uri_generator)
    end

    def self.async_provider
      EventMachineAsyncProvider.new
    end

    def initialize(node)
      @node = node
    end

    attr_reader :node, :update_fiber, :running

    def start(options = {})
      @runner = ::Goliath::Runner.new(ARGV, nil)
      @runner.api = HttpJsonRpcResponder.new(node)
      @runner.app = ::Goliath::Rack::Builder.build(HttpJsonRpcResponder, @runner.api)
      @runner.address = options[:address] if options[:address]
      @runner.port = options[:port] if options[:port]
      @runner.run
      @running = true

      update_proc = proc do
        EM.synchrony do
          @node.update
        end
      end
      @update_timer = EventMachine.add_periodic_timer(node.config.update_interval, update_proc)
      #      @node.update
    end

    def stop
      @update_timer.cancel
    end
  end
end
