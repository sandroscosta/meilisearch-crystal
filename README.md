# meilisearch-crystal

A type-safe [Meilisearch](https://www.meilisearch.com) client for Crystal,
inspired by the official [meilisearch-ruby](https://github.com/meilisearch/meilisearch-ruby)
SDK and the architecture of [jgaskins/meilisearch](https://github.com/jgaskins/meilisearch).

- **Type-safe at the boundary.** Server schema is fully typed (`Index`, `Query`,
  `Task`, `Key`, errors). Documents and search hits default to `JSON::Any` and
  opt into concrete types with `as: Book`.
- **Async tasks, first-class.** Mutations return `TaskResult`s; wait on them
  with `client.wait_for_task` (fiber-friendly, non-blocking).
- **Streaming document uploads.** Upsert an `Enumerable` and documents stream
  to Meilisearch as NDJSON — constant memory, lazy iterators supported.
- **Framework-agnostic.** No ORM, no framework bindings. Works from Lucky,
  Kemal, Athena, or bare scripts.
- **Zero runtime dependencies.** Only the Crystal stdlib (`http`, `json`).

[![CI](https://github.com/<your-github-user>/meilisearch-crystal/actions/workflows/ci.yml/badge.svg)](https://github.com/<your-github-user>/meilisearch-crystal/actions/workflows/ci.yml)
[![GitHub Pages](https://img.shields.io/badge/docs-github%20pages-blue)](https://<your-github-user>.github.io/meilisearch-crystal/)

## Table of contents

- [Quick start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Typed vs raw results](#typed-vs-raw-results)
- [Documents](#documents)
- [Search](#search)
- [Settings](#settings)
- [Tasks](#tasks)
- [API keys](#api-keys)
- [Usage notes](#usage-notes)
- [Development](#development)
- [API docs](#api-docs)

## Quick start

```crystal
require "meilisearch-crystal"

client = Meilisearch::Crystal::Client.new(
  url: "http://localhost:7700",
  api_key: "masterKey",
)

client.indexes.create "books", primary_key: "id"
# => Meilisearch::Crystal::TaskResult

book = {id: 1, title: "Shazam", rating: 7.5}
client.index("books").upsert [book]
# => Meilisearch::Crystal::TaskResult

client.index("books").search("shazam").hits
# => [{"id" => 1_i64, "title" => "Shazam", "rating" => 7.5}]
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     meilisearch-crystal:
       github: <your-github-user>/meilisearch-crystal
   ```

2. Run `shards install`

## Configuration

Configure defaults once, then use `Meilisearch::Crystal.client`:

```crystal
Meilisearch::Crystal.configure do |config|
  config.url     = ENV["MEILISEARCH_URL"]     # default http://localhost:7700
  config.api_key = ENV["MEILISEARCH_API_KEY"]
  config.timeout = 5.seconds                  # default 5 seconds
end

client = Meilisearch::Crystal.client   # built lazily from the above
```

Or construct clients explicitly — great for multiple instances:

```crystal
prod = Meilisearch::Crystal::Client.new(url: "https://meili.prod.example", api_key: "...")
staging = Meilisearch::Crystal::Client.new(url: "https://meili.staging.example", api_key: "...")
```

When constructed without arguments, `Client.new` falls back to the
`MEILISEARCH_URL` / `MEILISEARCH_API_KEY` environment variables.

## Typed vs raw results

Documents and search hits are *your* domain types, so the client doesn't force
one on you. By default you get `JSON::Any`; pass `as:` to get a typed array.

```crystal
struct Book
  include JSON::Serializable

  getter id : Int32
  getter title : String
  getter rating : Float64?
end

# raw — no types needed:
results = client.index("books").search("shazam")
results.hits                      # Array(JSON::Any)

# typed — compile-time checked:
results = client.index("books").search("shazam", as: Book)
results.hits                      # Array(Book)
```

## Documents

```crystal
index = client.index("books")

# upsert (add or replace, keyed by primary key)
index.upsert [{id: 1, title: "Shazam"}]
index.upsert! [{id: 1, title: "Shazam"}]            # blocking: waits for the task

# upsert-patch (add or merge, missing fields preserved)
index.upsert_patch [{id: 1, rating: 7.5}]

# fetch documents (POST documents/fetch) — raw or typed
index.fetch(limit: 10, as: Book)

# delete documents
index.delete(1)                                       # by primary key
index.delete(filter: "rating < 5")                    # matching a filter

# streaming upsert — bounded memory, works with any Enumerable
client.index("books").upsert PostQuery.new            # e.g. a DB iterator
```

## Search

```crystal
index.search("shazam", limit: 10, filter: "rating > 5", sort: ["rating:desc"])
# => Meilisearch::Crystal::SearchResponse(JSON::Any)

index.facet_search("genres", "fiction", filter: "rating > 3")
# => Meilisearch::Crystal::FacetSearchResponse

index.similar(1, embedder: "default", as: Book)

# multi-search across indexes, optionally federated:
client.multi_search [client.query(index_uid: "books", q: "shazam")], as: Book
client.federated_search [client.query(index_uid: "books", q: "shazam")], limit: 20
```

## Settings

```crystal
settings = client.indexes.settings.get("books")       # typed Settings struct
client.indexes.settings.update("books",
  filterable_attributes: ["rating"],
  sortable_attributes: ["rating"],
)
client.indexes.settings.reset("books")
```

## Tasks

```crystal
task = client.index("books").upsert [{id: 1, title: "Shazam"}]
client.wait_for_task(task)                            # blocks this fiber, not the process
task.status.succeeded?                                # enum predicate
```

## API keys

```crystal
key = client.keys.create(actions: ["search"], indexes: ["books"])
client.keys.list
client.keys.get?(key.uid)
client.keys.delete(key.uid)
```

## Usage notes

- All mutating operations are asynchronous in Meilisearch: they return a
  `TaskResult`. Use `client.wait_for_task(...)` or the `!`-suffixed variants
  when you need synchronous behavior.
- Document types only need `to_json(JSON::Builder)` to be upserted, and
  `from_json` (e.g. via `JSON::Serializable`) to be fetched typed. Anything
  with those is valid — `NamedTuple`s, `Hash(String, JSON::Any)`, or your own
  structs.
- The client does not auto-retry requests; handle errors where they matter.
  Server-originated failures raise `Meilisearch::Crystal::Error` with a typed
  error code.

## Development

```sh
shards install

# unit specs (webmock-based, no server needed)
crystal spec spec/meilisearch/crystal/*_spec.cr

# integration specs — spin up a real Meilisearch first:
docker run --rm -p 7700:7700 -e MEILI_MASTER_KEY=test-master-key getmeili/meilisearch:latest
crystal spec

# lint + format
# ameba v1.7.0-dev is installed from source; compile and run the CLI source.
crystal run lib/ameba/bin/ameba.cr
crystal tool format --check
```

## API docs

Generated API documentation is published to GitHub Pages from `main` and is
available at <https://<your-github-user>.github.io/meilisearch-crystal/>.
Build locally with:

```sh
crystal docs
```

## Contributors

- [Sandro Costa](https://github.com/<your-github-user>) - creator and maintainer
