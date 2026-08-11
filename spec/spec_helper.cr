require "spec"
require "../src/meilisearch-crystal"
require "webmock"

# Re-enables real localhost HTTP after unit examples reset WebMock.
def allow_integration_connections : Nil
  WebMock.allow_net_connect = true
end

# Yields with the given environment variables set, restoring the previous
# values afterwards.
def with_env(overrides : Hash(String, String), &)
  previous = Hash(String, String | ::Nil).new
  overrides.each do |key, value|
    previous[key] = ENV[key]?
    ENV[key] = value
  end
  begin
    yield
  ensure
    previous.each do |key, value|
      if value
        ENV[key] = value
      else
        ENV.delete(key)
      end
    end
  end
end
