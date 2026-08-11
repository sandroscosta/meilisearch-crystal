require "spec"
require "../src/meilisearch-crystal"

# Yields with the given environment variables set, restoring the previous
# values afterwards.
def with_env(overrides : Hash(String, String), &)
  previous = {} of String => String?
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
