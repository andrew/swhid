## [Unreleased]

## [0.3.0] - 2025-11-23

- `directory` CLI command - Generate SWHID for directory from filesystem
- `revision` CLI command - Generate SWHID for git commit/revision
- `release` CLI command - Generate SWHID for git tag/release
- `snapshot` CLI command - Generate SWHID for git repository snapshot

## [0.2.1] - 2025-11-09

- Package manager tests for PyPI, RubyGems, Maven, Cargo, and NPM artifacts (content and extracted directories)
- Filesystem directory SWHID computation helper

## [0.2.0] - 2025-11-09

- Full implementation of all SWHID object types (content, directory, revision, release, snapshot)
- Cross-implementation validation against Python swh-model library
- CLI tool with JSON output support
- Performance benchmarks
- Bug fixes for directory permissions and revision timestamp handling

## [0.1.0] - 2025-11-09

- Initial release
