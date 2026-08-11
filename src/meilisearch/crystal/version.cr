module Meilisearch::Crystal
  # The shard version, read from `shard.yml` at compile time.
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
end
