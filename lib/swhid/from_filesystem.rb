# frozen_string_literal: true

require "digest/sha1"
require "find"

module Swhid
  module FromFilesystem
    def self.from_directory_path(path, git_repo: nil, permissions: nil)
      raise ArgumentError, "Path does not exist: #{path}" unless File.exist?(path)
      raise ArgumentError, "Path is not a directory: #{path}" unless File.directory?(path)

      git_repo ||= discover_git_repo(path)
      repo_relative_path = relative_path_in_repo(path, git_repo) if git_repo
      index_entries = load_git_index_entries(git_repo)
      compute_directory_path(
        path,
        git_repo: git_repo,
        permissions: permissions,
        repo_relative_path: repo_relative_path,
        index_entries: index_entries
      )
    end

    def self.compute_directory_path(path, git_repo:, permissions:, repo_relative_path:, index_entries:)
      entries = build_entries(
        path,
        git_repo: git_repo,
        permissions: permissions,
        repo_relative_path: repo_relative_path,
        index_entries: index_entries
      )
      Swhid.from_directory(entries)
    end

    def self.discover_git_repo(path)
      require "rugged"
      Rugged::Repository.discover(path)
    rescue Rugged::RepositoryError, Rugged::OSError
      nil
    end

    def self.build_entries(dir_path, git_repo: nil, permissions: nil, repo_relative_path: nil, index_entries: nil)
      entries = []
      index_entries ||= load_git_index_entries(git_repo)

      Dir.foreach(dir_path) do |name|
        next if name == "." || name == ".."
        next if name == ".git"

        full_path = File.join(dir_path, name)
        stat = File.lstat(full_path)
        relative_path = if repo_relative_path
                          repo_relative_path.empty? ? name : "#{repo_relative_path}/#{name}"
                        end
        index_entry = relative_path && index_entries[relative_path]

        entry = if index_entry && (index_entry[:mode] & 0o170000) == 0o160000
                  { name: name, type: :rev, target: index_entry[:oid] }
                elsif File.symlink?(full_path)
                  target_content = File.readlink(full_path)
                  target_hash = Swhid.from_content(target_content).object_hash
                  { name: name, type: :symlink, target: target_hash }
                elsif stat.directory?
                  target_swhid = compute_directory_path(
                    full_path,
                    git_repo: git_repo,
                    permissions: permissions,
                    repo_relative_path: relative_path,
                    index_entries: index_entries
                  )
                  { name: name, type: :dir, target: target_swhid.object_hash }
                elsif file_executable?(
                  full_path,
                  stat,
                  git_repo,
                  permissions,
                  index_entry: index_entry,
                  index_checked: true
                )
                  target_hash = content_swhid_from_file(full_path, stat.size).object_hash
                  { name: name, type: :exec, target: target_hash }
                else
                  target_hash = content_swhid_from_file(full_path, stat.size).object_hash
                  { name: name, type: :file, target: target_hash }
                end

        entries << entry
      end

      entries
    end

    def self.content_swhid_from_file(path, size)
      File.open(path, "rb") do |file|
        Swhid.from_content_io(file, size: size)
      end
    end

    def self.file_executable?(full_path, stat, git_repo, permissions = nil, index_entry: nil, index_checked: false)
      # Check explicit permissions map first (from tar extraction, etc.)
      if permissions
        real_path = File.realpath(full_path) rescue File.expand_path(full_path)
        mode = permissions[full_path] || permissions[real_path]
        return (mode & 0o111) != 0 if mode
      end

      # Check Git index for tracked files
      if git_repo
        index_entry ||= git_index_entry(full_path, git_repo) unless index_checked
        return (index_entry[:mode] & 0o111) != 0 if index_entry
      end

      # Fall back to filesystem
      stat.executable?
    end

    def self.git_index_entry(full_path, git_repo)
      return nil unless git_repo

      relative_path = relative_path_in_repo(full_path, git_repo)
      relative_path && git_repo.index[relative_path]
    end

    def self.load_git_index_entries(git_repo)
      return {} unless git_repo

      git_repo.index.each_with_object({}) do |entry, entries|
        entries[entry[:path]] = entry if entry[:stage].zero?
      end
    end

    def self.relative_path_in_repo(full_path, git_repo)
      repo_workdir = git_repo.workdir
      return nil unless repo_workdir

      # Use realpath to resolve symlinks (e.g., /tmp -> /private/tmp on macOS)
      full_path = File.realpath(full_path) rescue File.expand_path(full_path)
      repo_workdir = File.realpath(repo_workdir) rescue File.expand_path(repo_workdir)

      # Normalize path separators for consistent comparison (especially on Windows)
      full_path = full_path.tr("\\", "/")
      repo_workdir = repo_workdir.tr("\\", "/")

      repo_workdir = repo_workdir.chomp("/")
      return "" if full_path == repo_workdir

      repo_prefix = "#{repo_workdir}/"
      return nil unless full_path.start_with?(repo_prefix)

      full_path.delete_prefix(repo_prefix)
    end
  end
end
