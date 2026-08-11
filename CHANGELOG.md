# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.0] - 2026-08-11

### Added

- Typed clients for indexes, documents, search, settings, tasks, batches,
  API keys, server health/version/stats, dumps, snapshots, experimental
  features, and network configuration.
- Boundary typing for fetched documents and search hits, including facet,
  similar, multi-index, and federated search responses.
- Discriminated task models, task polling, blocking mutation helpers, and
  streaming NDJSON document ingestion.
- HS256 tenant-token generation and index-scoped tenant clients.
- Unit coverage with WebMock and integration coverage against the pinned
  Meilisearch v1.53.0 Docker image.
- Generated API documentation, Ameba linting, formatting checks, and CI for
  Crystal 1.20.3 and the latest stable Crystal release.

[Unreleased]: https://github.com/sandroscosta/meilisearch-crystal/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sandroscosta/meilisearch-crystal/releases/tag/v0.1.0
