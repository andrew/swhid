#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "swhid"
require "benchmark"
require "stringio"
require "tmpdir"

puts "SWHID Performance Benchmarks"
puts "=" * 60
puts

# Benchmark content hashing
puts "Content (blob) hashing:"
content_small = "Hello, World!"
content_medium = "x" * 10_000
content_large = "x" * 1_000_000

Benchmark.bm(30) do |x|
  x.report("Small content (13 bytes):") do
    10_000.times { Swhid.from_content(content_small) }
  end

  x.report("Medium content (10 KB):") do
    1_000.times { Swhid.from_content(content_medium) }
  end

  x.report("Large content (1 MB):") do
    100.times { Swhid.from_content(content_large) }
  end

  x.report("Large content IO (1 MB):") do
    100.times do
      Swhid.from_content_io(StringIO.new(content_large), size: content_large.bytesize)
    end
  end
end

puts
puts "=" * 60
puts
puts "Filesystem directory hashing:"

Dir.mktmpdir("swhid-benchmark") do |directory_path|
  require "rugged"
  repository = Rugged::Repository.init_at(directory_path)
  1_000.times do |i|
    File.binwrite(File.join(directory_path, "file#{i}.txt"), "content #{i}\n")
  end
  repository.index.add_all
  repository.index.write

  Benchmark.bm(30) do |x|
    x.report("Filesystem (1,000 files):") do
      10.times { Swhid::FromFilesystem.from_directory_path(directory_path) }
    end
  end
end

puts
puts "=" * 60
puts

# Benchmark directory hashing
puts "Directory (tree) hashing:"

entries_small = [
  { name: "README.md", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
]

entries_medium = 10.times.map do |i|
  { name: "file#{i}.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
end

entries_large = 100.times.map do |i|
  { name: "file#{i}.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
end

entries_xlarge = 1_000.times.map do |i|
  { name: "file#{i}.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
end

Benchmark.bm(30) do |x|
  x.report("Small directory (1 entry):") do
    10_000.times { Swhid.from_directory(entries_small) }
  end

  x.report("Medium directory (10 entries):") do
    5_000.times { Swhid.from_directory(entries_medium) }
  end

  x.report("Large directory (100 entries):") do
    1_000.times { Swhid.from_directory(entries_large) }
  end

  x.report("XL directory (1,000 entries):") do
    100.times { Swhid.from_directory(entries_xlarge) }
  end
end

puts
puts "=" * 60
puts

# Benchmark snapshot hashing
puts "Snapshot hashing:"

branches = 1_000.times.map do |i|
  { name: "refs/heads/branch#{i}", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
end

Benchmark.bm(30) do |x|
  x.report("Snapshot (1,000 branches):") do
    100.times { Swhid.from_snapshot(branches) }
  end
end

puts
puts "=" * 60
puts

# Benchmark revision hashing
puts "Revision (commit) hashing:"

revision_metadata = {
  directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
  author: "John Doe <john@example.com>",
  author_timestamp: 1234567890,
  committer: "Jane Smith <jane@example.com>",
  committer_timestamp: 1234567890,
  message: "Initial commit"
}

Benchmark.bm(30) do |x|
  x.report("Revision (simple):") do
    10_000.times { Swhid.from_revision(revision_metadata) }
  end

  x.report("Revision (with parents):") do
    10_000.times do
      Swhid.from_revision(revision_metadata.merge(
        parents: ["94a9ed024d3859793618152ea559a168bbcbb5e2"]
      ))
    end
  end
end

puts
puts "=" * 60
puts

# Benchmark SWHID parsing
puts "SWHID parsing:"

swhid_simple = "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2"
swhid_with_qualifiers = "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=https://github.com/example/repo;lines=1-10"

Benchmark.bm(30) do |x|
  x.report("Parse simple SWHID:") do
    10_000.times { Swhid.parse(swhid_simple) }
  end

  x.report("Parse SWHID with qualifiers:") do
    10_000.times { Swhid.parse(swhid_with_qualifiers) }
  end
end

puts
puts "=" * 60
puts "Benchmark complete!"
