# frozen_string_literal: true

require "json"
require "rack"

module GraphQLMCP
  # Serves the schema's operations as MCP tools over Streamable HTTP
  class RackApp
    attr_reader :tools

    # context: a callable that receives the Rack request and returns the GraphQL context, or nil to reject it with 401
    # only / except: tool names (root field names, like "createPost") to expose or to leave out
    # allowed_hosts: Host header values accepted besides loopback, see the SDK's DNS rebinding protection
    def initialize(schema:, context:, name: schema.name.to_s, only: nil, except: nil, allowed_hosts: nil) # rubocop:disable Metrics/ParameterLists
      @name = name
      @context = context
      @allowed_hosts = allowed_hosts
      @tools = select_operations(Operations.new(schema), only:, except:).map(&:to_tool)

      # GraphQL validates arguments itself, so its errors reach clients unchanged
      @configuration = MCP::Configuration.new(validate_tool_call_arguments: false)
    end

    def call(env)
      graphql_context = @context.call(Rack::Request.new(env))
      return unauthorized unless graphql_context

      # The SDK passes context to tools only through the server, so a stateless server is built per request
      server = MCP::Server.new(
        name: @name,
        version: GraphQLMCP::VERSION,
        tools: @tools,
        server_context: { graphql_context: },
        configuration: @configuration,
      )

      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        allowed_hosts: @allowed_hosts,
      )

      transport.call(env)
    end

    private

    def select_operations(operations, only:, except:)
      raise ArgumentError, "Pass either only: or except:, not both" if only && except
      return operations.to_a unless only || except

      names = Array(only || except).map(&:to_s)
      check_names!(names, operations.map(&:name))

      if only
        operations.select { |operation| names.include?(operation.name) }
      else
        operations.reject { |operation| names.include?(operation.name) }
      end
    end

    # A misspelled name would silently expose or hide the wrong tools, so it fails at boot instead
    def check_names!(names, available)
      unknown = names - available
      return if unknown.empty?

      spell_checker = DidYouMean::SpellChecker.new(dictionary: available)
      details = unknown.map do |name|
        suggestion = spell_checker.correct(name).first
        suggestion ? "#{name} (did you mean #{suggestion}?)" : name
      end

      raise Error, "Unknown or hidden operations: #{details.join(', ')}"
    end

    def unauthorized
      body = JSON.generate(error: "Unauthorized")
      [401, { "content-type" => "application/json", "www-authenticate" => "Bearer" }, [body]]
    end
  end
end
