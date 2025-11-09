# Swhid

A Ruby library and CLI for generating and parsing SoftWare Hash IDentifiers (SWHIDs).

SWHIDs are persistent, intrinsic identifiers for software artifacts such as files, directories, commits, releases, and snapshots. They are content-based identifiers that use Merkle DAGs for tamper-proof identification with built-in integrity verification.

This implementation follows the official [SWHID specification v1.2](https://www.swhid.org/specification) (ISO/IEC 18670:2025).

## Features

- Generate SWHIDs for all object types:
  - Content (cnt) - files and blobs
  - Directory (dir) - directory trees
  - Revision (rev) - commits
  - Release (rel) - tags and releases
  - Snapshot (snp) - repository snapshots
- Parse and validate SWHID strings
- Support for qualifiers (origin, visit, anchor, path, lines, bytes)
- Command-line interface for easy integration
- Git-compatible hash computation
- Comprehensive test suite

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'swhid'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install swhid
```

## Usage

### Library Usage

#### Parsing SWHIDs

```ruby
require 'swhid'

# Parse a SWHID string
swhid = Swhid.parse("swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2")

puts swhid.scheme       # => "swh"
puts swhid.version      # => 1
puts swhid.object_type  # => "cnt"
puts swhid.object_hash  # => "94a9ed024d3859793618152ea559a168bbcbb5e2"
puts swhid.to_s         # => "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2"

# Parse SWHID with qualifiers
swhid = Swhid.parse("swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=https://github.com/example/repo;lines=5-10")
puts swhid.qualifiers[:origin] # => "https://github.com/example/repo"
puts swhid.qualifiers[:lines]  # => "5-10"
```

#### Generating SWHIDs

**Content (Files)**

```ruby
# From a file
content = File.read("example.txt")
swhid = Swhid.from_content(content)
puts swhid.to_s # => "swh:1:cnt:..."

# Empty file
swhid = Swhid.from_content("")
puts swhid.to_s # => "swh:1:cnt:e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
```

**Directory**

```ruby
entries = [
  { name: "README.md", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
  { name: "src", type: :dir, target: "4b825dc642cb6eb9a060e54bf8d69288fbee4904" },
  { name: "script.sh", type: :exec, target: "84a9ed024d3859793618152ea559a168bbcbb5e1" }
]

swhid = Swhid.from_directory(entries)
puts swhid.to_s
```

**Revision (Commit)**

```ruby
metadata = {
  directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
  author: "John Doe <john@example.com>",
  author_timestamp: 1234567890,
  author_timezone: "+0000",
  committer: "Jane Smith <jane@example.com>",
  committer_timestamp: 1234567890,
  committer_timezone: "+0000",
  message: "Initial commit",
  parents: [] # Optional
}

swhid = Swhid.from_revision(metadata)
puts swhid.to_s
```

**Release (Tag)**

```ruby
metadata = {
  name: "v1.0.0",
  target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" },
  author: "John Doe <john@example.com>",
  author_timestamp: 1234567890,
  message: "Release version 1.0.0"
}

swhid = Swhid.from_release(metadata)
puts swhid.to_s
```

**Snapshot**

```ruby
branches = [
  { name: "refs/heads/main", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
  { name: "refs/tags/v1.0", target_type: "release", target: "84a9ed024d3859793618152ea559a168bbcbb5e1" },
  { name: "HEAD", target_type: "alias", target: "refs/heads/main" }
]

swhid = Swhid.from_snapshot(branches)
puts swhid.to_s
```

**Working with Qualifiers**

```ruby
# Create SWHID with qualifiers
swhid = Swhid::Identifier.new(
  object_type: "cnt",
  object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2",
  qualifiers: {
    origin: "https://github.com/example/repo",
    visit: "swh:1:snp:d7f1b9eb7ccb596c2622c4780febaa02549830f9",
    anchor: "swh:1:rev:2db189928c94d62a3b4757b3eec68f0a4d4113f0",
    path: "/src/main.rb",
    lines: "10-20"
  }
)

puts swhid.to_s
# => "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=https://github.com/example/repo;visit=swh:1:snp:...;anchor=swh:1:rev:...;path=/src/main.rb;lines=10-20"
```

### CLI Usage

The gem includes a command-line tool for working with SWHIDs:

**Parse a SWHID**

```bash
$ swhid parse "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2"
SWHID: swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2
Core:  swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2
Type:  cnt
Hash:  94a9ed024d3859793618152ea559a168bbcbb5e2
```

**Generate SWHID from file content**

```bash
$ cat file.txt | swhid content
swh:1:cnt:9daeafb9864cf43055ae93beb0afd6c7d144bfa4

$ echo "Hello, World!" | swhid content
swh:1:cnt:96898574d1b88e619be24fd90bb4cd399acbc5ca
```

**Add qualifiers**

```bash
$ cat file.txt | swhid content -q origin=https://github.com/example/repo -q lines=1-10
swh:1:cnt:9daeafb9864cf43055ae93beb0afd6c7d144bfa4;origin=https://github.com/example/repo;lines=1-10
```

**JSON output**

```bash
$ swhid parse "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2" -f json
{
  "swhid": "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2",
  "core": "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2",
  "object_type": "cnt",
  "object_hash": "94a9ed024d3859793618152ea559a168bbcbb5e2",
  "qualifiers": {}
}
```

## Object Types

- **cnt** (content): Individual files or blobs
- **dir** (directory): Directory trees with entries
- **rev** (revision): Git commits or equivalent
- **rel** (release): Tags or releases
- **snp** (snapshot): Repository snapshots at a point in time

## Qualifiers

SWHIDs can include optional qualifiers to provide context:

- **origin**: URL of the software origin
- **visit**: Core SWHID of the snapshot when visited
- **anchor**: Core SWHID of the anchor node (directory, revision, release, or snapshot)
- **path**: Absolute file path from the root directory
- **lines**: Line range (e.g., "10-20")
- **bytes**: Byte range (e.g., "100-500")

## Git Compatibility

The hash computation for content, directory, revision, and release objects is compatible with Git's object hashing. This means you can use this gem to compute the same hashes that Git would produce for the same objects.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/swhid. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/swhid/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Swhid project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/swhid/blob/main/CODE_OF_CONDUCT.md).
