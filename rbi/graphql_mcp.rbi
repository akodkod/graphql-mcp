# typed: strong

# Shipped with the gem so Tapioca imports these signatures into host applications
module GraphQLMCP
  VERSION = T.let(T.unsafe(nil), String)

  class Error < StandardError; end
end
