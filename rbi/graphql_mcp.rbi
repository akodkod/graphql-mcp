# typed: strong

# Shipped with the gem so Tapioca imports these signatures into host applications
module GraphQLMCP
  VERSION = T.let(T.unsafe(nil), String)

  class Error < StandardError; end

  sig do
    params(
      schema: T.class_of(GraphQL::Schema),
      context: T.proc.params(request: Rack::Request).returns(T.nilable(T::Hash[Symbol, T.untyped])),
      name: String,
      only: T.nilable(T::Array[T.any(String, Symbol)]),
      except: T.nilable(T::Array[T.any(String, Symbol)]),
      depth: Integer,
      allowed_hosts: T.nilable(T::Array[String]),
    ).returns(GraphQLMCP::RackApp)
  end
  def self.from_schema(schema, context:, name: T.unsafe(nil), only: nil, except: nil, depth: 1, allowed_hosts: nil); end

  # A Rack app that serves the schema's operations as MCP tools
  class RackApp
    sig { params(env: T::Hash[String, T.untyped]).returns([Integer, T::Hash[String, String], T.untyped]) }
    def call(env); end
  end
end
