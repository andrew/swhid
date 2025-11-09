# frozen_string_literal: true

require "digest/sha1"
require "find"

module Swhid
  module FromFilesystem
    def self.from_directory_path(path)
      raise ArgumentError, "Path does not exist: #{path}" unless File.exist?(path)
      raise ArgumentError, "Path is not a directory: #{path}" unless File.directory?(path)

      entries = build_entries(path)
      Swhid.from_directory(entries)
    end

    def self.build_entries(dir_path)
      entries = []

      Dir.foreach(dir_path) do |name|
        next if name == "." || name == ".."
        next if name == ".git"

        full_path = File.join(dir_path, name)
        stat = File.lstat(full_path)

        entry = if File.symlink?(full_path)
                  target_content = File.readlink(full_path)
                  target_hash = Swhid.from_content(target_content).object_hash
                  { name: name, type: :symlink, target: target_hash }
                elsif stat.directory?
                  target_swhid = from_directory_path(full_path)
                  { name: name, type: :dir, target: target_swhid.object_hash }
                elsif stat.executable?
                  content = File.binread(full_path)
                  target_hash = Swhid.from_content(content).object_hash
                  { name: name, type: :exec, target: target_hash }
                else
                  content = File.binread(full_path)
                  target_hash = Swhid.from_content(content).object_hash
                  { name: name, type: :file, target: target_hash }
                end

        entries << entry
      end

      entries
    end
  end
end
