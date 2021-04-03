module Raft
  class Goliath
    class HttpJsonRpcResponder < ::Goliath::API
      use ::Goliath::Rack::Render, 'json'
      use ::Goliath::Rack::Validation::RequestMethod, %w[POST]
      use ::Goliath::Rack::Params

      def initialize(node)
        @node = node
      end

      HEADERS = { 'Content-Type' => 'application/json' }

      def response(env)
        case env['REQUEST_PATH']
        when '/request_vote'
          handle_errors { request_vote_response(env['params']) }
        when '/append_entries'
          handle_errors { append_entries_response(env['params']) }
        when '/command'
          handle_errors { command_response(env['params']) }
        else
          error_response(404, 'not found')
        end
      end

      def request_vote_response(params)
        print("\nnode #{@node.id} received request_vote from #{params['candidate_id']}, term #{params['term']}\n")
        request = Raft::RequestVoteRequest.new(
          params['term'],
          params['candidate_id'],
          params['last_log_index'],
          params['last_log_term']
        )
        response = @node.handle_request_vote(request)
        [200, HEADERS, { 'term' => response.term, 'vote_granted' => response.vote_granted }]
      end

      def append_entries_response(params)
        print("\nnode #{@node.id} received append_entries from #{params['leader_id']}, term #{params['term']}\n")
        entries = params['entries'].map { |entry| Raft::LogEntry.new(entry['term'], entry['index'], entry['command']) }
        request = Raft::AppendEntriesRequest.new(
          params['term'],
          params['leader_id'],
          params['prev_log_index'],
          params['prev_log_term'],
          entries,
          params['commit_index']
        )
        print("\nnode #{@node.id} received entries: #{request.entries.pretty_inspect}\n")
        response = @node.handle_append_entries(request)
        print("\nnode #{@node.id} completed append_entries from #{params['leader_id']}, term #{params['term']} (#{response})\n")
        [200, HEADERS, { 'term' => response.term, 'success' => response.success }]
      end

      def command_response(params)
        p params
        request = Raft::CommandRequest.new(params['command'])
        response = @node.handle_command(request)
        [response.success ? 200 : 409, HEADERS, { 'success' => response.success }]
      end

      def handle_errors
        yield
      rescue StandardError => e
        error_response(422, e)
      rescue Exception => e
        error_response(500, e)
      end

      def error_message(exception)
        "#{exception.message}\n\t#{exception.backtrace.join("\n\t")}".tap { |m| print("\n\n\t#{m}\n\n") }
      end

      def error_response(code, exception)
        [code, HEADERS, { 'error' => error_message(exception) }]
      end
    end

    module HashMarshalling
      def self.hash_to_object(hash, klass)
        object = klass.new
        hash.each_pair do |k, v|
          object.send("#{k}=", v)
        end
        object
      end

      def self.object_to_hash(object, attrs)
        attrs.each_with_object({}) do |attr, hash|
          hash[attr] = object.send(attr)
        end
      end
    end

    class HttpJsonRpcProvider < Raft::RpcProvider
      attr_reader :uri_generator

      def initialize(uri_generator)
        @uri_generator = uri_generator
      end

      def request_votes(request, cluster)
        sent_hash = HashMarshalling.object_to_hash(request, %w[term candidate_id last_log_index last_log_term])
        sent_json = MultiJson.dump(sent_hash)
        deferred_calls = []
        EM.synchrony do
          cluster.node_ids.each do |node_id|
            next if node_id == request.candidate_id

            http = EventMachine::HttpRequest.new(uri_generator.call(node_id, 'request_vote')).post(
              body: sent_json,
              head: { 'Content-Type' => 'application/json' }
            )
            http.callback do
              if http.response_header.status == 200
                received_hash = MultiJson.load(http.response)
                response = HashMarshalling.hash_to_object(received_hash, Raft::RequestVoteResponse)
                print("\n\t#{node_id} responded #{response.vote_granted} to #{request.candidate_id}\n\n")
                yield node_id, request, response
              else
                Raft::Goliath.log("request_vote failed for node '#{node_id}' with code #{http.response_header.status}")
              end
            end
            deferred_calls << http
          end
        end
        deferred_calls.each do |http|
          EM::Synchrony.sync http
        end
      end

      def append_entries(request, cluster, &block)
        deferred_calls = []
        EM.synchrony do
          cluster.node_ids.each do |node_id|
            next if node_id == request.leader_id

            deferred_calls << create_append_entries_to_follower_request(request, node_id, &block)
          end
        end
        deferred_calls.each do |http|
          EM::Synchrony.sync http
        end
      end

      def append_entries_to_follower(request, node_id, &block)
        #        EM.synchrony do
        create_append_entries_to_follower_request(request, node_id, &block)
        #        end
      end

      def create_append_entries_to_follower_request(request, node_id)
        sent_hash = HashMarshalling.object_to_hash(request,
                                                   %w[term leader_id prev_log_index prev_log_term entries commit_index])
        sent_hash['entries'] = sent_hash['entries'].map do |obj|
          HashMarshalling.object_to_hash(obj, %w[term index command])
        end
        sent_json = MultiJson.dump(sent_hash)
        raise 'replicating to self!' if request.leader_id == node_id

        print("\nleader #{request.leader_id} replicating entries to #{node_id}: #{sent_hash.pretty_inspect}\n")#"\t#{caller[0..4].join("\n\t")}")

        http = EventMachine::HttpRequest.new(uri_generator.call(node_id, 'append_entries')).post(
          body: sent_json,
          head: { 'Content-Type' => 'application/json' }
        )
        http.callback do
          print("\nleader #{request.leader_id} calling back to #{node_id} to append entries\n")
          if http.response_header.status == 200
            received_hash = MultiJson.load(http.response)
            response = HashMarshalling.hash_to_object(received_hash, Raft::AppendEntriesResponse)
            yield node_id, response
          else
            Raft::Goliath.log("append_entries failed for node '#{node_id}' with code #{http.response_header.status}")
          end
        end
        http
      end

      def command(request, node_id)
        sent_hash = HashMarshalling.object_to_hash(request, %w[command])
        sent_json = MultiJson.dump(sent_hash)
        http = EventMachine::HttpRequest.new(uri_generator.call(node_id, 'command')).post(
          body: sent_json,
          head: { 'Content-Type' => 'application/json' }
        )
        http = EM::Synchrony.sync(http)
        if http.response_header.status == 200
          received_hash = MultiJson.load(http.response)
          HashMarshalling.hash_to_object(received_hash, Raft::CommandResponse)
        else
          Raft::Goliath.log("command failed for node '#{node_id}' with code #{http.response_header.status}")
          CommandResponse.new(false)
        end
      end
    end
  end
end
