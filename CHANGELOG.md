# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.0.2] - 2025-10-20
### Fixed
- Mark the package as Flutter (`flutter` SDK + `flutter` dependency) so pub.dev analyzes it correctly.
- Add public API docs and analysis options.

## [0.0.1] - 2025-10-19
### Added
- Initial release of **sqlite_inspector**.
  - First public release.
  - Dev-only HTTP server (`SqliteInspector.start()`) to browse/query on-device SQLite from VS Code.
  - Endpoints: /v1/health, /v1/databases, /v1/tables, /v1/schema, /v1/data-version, /v1/query, /v1/exec, /v1/batch, /v1/config.
  - Safe defaults: loopback-only, DDL disabled by default, optional x-debug-token.