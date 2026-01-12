# frozen_string_literal: true

require "digest/sha1"
require "find"

module Swhid
  module FromFilesystem
    def self.from_directory_path(path, git_repo: nil, permissions: nil)
      raise ArgumentError, "Path does not exist: #{path}" unless File.exist?(path)
      raise ArgumentError, "Path is not a directory: #{path}" unless File.directory?(path)

      git_repo ||= discover_git_repo(path)
      entries = build_entries(path, git_repo: git_repo, permissions: permissions)
      Swhid.from_directory(entries)
    end

    def self.discover_git_repo(path)
      require "rugged"
      Rugged::Repository.discover(path)
    rescue Rugged::RepositoryError, Rugged::OSError
      nil
    end

    def self.build_entries(dir_path, git_repo: nil, permissions: nil)
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
                  target_swhid = from_directory_path(full_path, git_repo: git_repo, permissions: permissions)
                  { name: name, type: :dir, target: target_swhid.object_hash }
                elsif file_executable?(full_path, stat, git_repo, permissions)
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

    def self.file_executable?(full_path, stat, git_repo, permissions = nil)
      # Check explicit permissions map first (from tar extraction, etc.)
      if permissions
        mode = permissions[full_path] || permissions[File.expand_path(full_path)]
        return (mode & 0o111) != 0 if mode
      end

      # Check Git index for tracked files
      if git_repo
        relative_path = relative_path_in_repo(full_path, git_repo)
        if relative_path
          entry = git_repo.index[relative_path]
          if entry
            mode = entry[:mode]
            return (mode & 0o111) != 0
          end
        end
      end

      # Fall back to filesystem
      stat.executable?
    end

    def self.relative_path_in_repo(full_path, git_repo)
      repo_workdir = git_repo.workdir
      return nil unless repo_workdir

      full_path = File.expand_path(full_path)
      repo_workdir = File.expand_path(repo_workdir)

      return nil unless full_path.start_with?(repo_workdir)

      relative = full_path.sub(repo_workdir, "")
      relative = relative[1..] if relative.start_with?("/") || relative.start_with?("\\")
      relative.tr("\\", "/")
    end
  end
end
