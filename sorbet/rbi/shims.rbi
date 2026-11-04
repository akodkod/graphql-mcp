# typed: true

# Stand-ins for dependency constants the shipped RBI refers to. Host applications get the real ones from Tapioca,
# so these are only for type-checking `rbi/` in this repository and are not part of the gem

module GraphQL
  class Schema; end
end

module Rack
  class Request; end
end
