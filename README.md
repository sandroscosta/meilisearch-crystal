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

[![CI](https://github.com/sandroscosta/meilisearch-crystal/actions/workflows/ci.yml/badge.svg)](https://github.com/sandroscosta/meilisearch-crystal/actions/workflows/ci.yml)
[![GitHub Pages](https://img.shields.io/badge/docs-github%20pages-blue)](https://sandroscosta.github.io/meilisearch-crystal/)

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

client.indexes.create("books", "id")
# => Meilisearch::Crystal::TaskResult

book = {id: 1, title: "Shazam", rating: 7.5}
client.index("books").documents.upsert("books", [book])
# => Meilisearch::Crystal::TaskResult

client.index("books").search("shazam").hits
# => [{"id" => 1_i64, "title" => "Shazam", "rating" => 7.5}]
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     meilisearch-crystal:
       github: sandroscosta/meilisearch-crystal
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
index.documents.upsert("books", [{id: 1, title: "Shazam"}])
index.documents.upsert!("books", [{id: 1, title: "Shazam"}]) # waits for the task

# upsert-patch (add or merge, missing fields preserved)
index.documents.upsert_patch("books", [{id: 1, rating: 7.5}])

# fetch documents (POST documents/fetch) — raw or typed
index.documents.fetch("books", limit: 10, as: Book)

# delete documents
index.documents.delete("books", 1)                    # by primary key
index.documents.delete("books", filter: "rating < 5") # matching a filter

# streaming upsert — bounded memory, works with any Enumerable
client.index("books").documents.upsert("books", PostQuery.new)
```

## Search

```crystal
query = Meilisearch::Crystal::Query.new(
  q: "shazam",
  limit: 10,
  filter: "rating > 5",
  sort: ["rating:desc"],
)
index.search(query)
# => Meilisearch::Crystal::SearchResponse(JSON::Any)

request = Meilisearch::Crystal::FacetSearchRequest.new(
  "genres",
  "fiction",
  filter: "rating > 3",
)
index.facet_search(request)
# => Meilisearch::Crystal::FacetSearchResponse

index.similar(1, "default", as: Book)

# multi-search across indexes, optionally federated:
queries = [Meilisearch::Crystal::Query.new(index_uid: "books", q: "shazam")]
client.search.multi(queries, as: Book)
client.search.federated(
  queries,
  Meilisearch::Crystal::MultiSearch::Federation.new(limit: 20),
  as: Book,
)
```

## Settings

```crystal
settings = client.index("books").settings             # typed Settings struct
client.settings.update("books", Meilisearch::Crystal::Settings.new(
  filterable_attributes: ["rating"],
  sortable_attributes: ["rating"],
))
client.settings.reset("books")
```

## Tasks

```crystal
task = client.index("books").documents.upsert("books", [{id: 1, title: "Shazam"}])
completed = client.wait_for_task(task)                # blocks this fiber, not the process
completed.succeeded?                                  # typed predicate
```

## API keys

```crystal
key = client.keys.create(["search"], ["books"])
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
  Server-originated failures raise `Meilisearch::Crystal::ApiError`, carrying
  a parsed `Meilisearch::Crystal::Error` with a typed error code.

## Development

```sh
shards install

# unit specs (webmock-based, no server needed)
crystal spec spec/meilisearch/crystal/*_spec.cr

# integration specs — spin up a real Meilisearch first:
docker run --rm -p 7700:7700 -e MEILI_MASTER_KEY=test-master-key getmeili/meilisearch:v1.53.0
MEILISEARCH_INTEGRATION=1 MEILISEARCH_API_KEY=test-master-key crystal spec

# lint + format
bin/ameba
crystal tool format --check
```

## API docs

Generated API documentation is published to GitHub Pages from `main` and is
available at <https://sandroscosta.github.io/meilisearch-crystal/>.
Build locally with:

```sh
crystal docs
```

## Contributors

- [Sandro Costa](https://github.com/sandroscosta) - creator and maintainer
