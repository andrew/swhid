# frozen_string_literal: true

require "rugged"

module Swhid
  module FromGit
    def self.from_revision(repo_path, ref = "HEAD")
      repo = Rugged::Repository.new(repo_path)
      commit = repo.rev_parse(ref)

      raise ArgumentError, "Reference #{ref} is not a commit" unless commit.is_a?(Rugged::Commit)

      metadata = {
        directory: commit.tree.oid,
        parents: commit.parents.map(&:oid),
        author: format_person(commit.author),
        author_timestamp: commit.author[:time].to_i,
        author_timezone: format_timezone(commit.author[:time]),
        committer: format_person(commit.committer),
        committer_timestamp: commit.committer[:time].to_i,
        committer_timezone: format_timezone(commit.committer[:time]),
        message: commit.message
      }

      # Extract extra headers if present (like gpgsig, svn headers, etc)
      extra_headers = extract_extra_headers(repo, commit)
      metadata[:extra_headers] = extra_headers unless extra_headers.empty?

      Swhid.from_revision(metadata)
    end

    def self.from_release(repo_path, tag_name)
      repo = Rugged::Repository.new(repo_path)
      tag_ref = repo.references["refs/tags/#{tag_name}"]

      raise ArgumentError, "Tag #{tag_name} not found" unless tag_ref

      # Get the tag object
      tag_obj = repo.lookup(tag_ref.target_id)

      # Check if it's an annotated tag
      if tag_obj.is_a?(Rugged::Tag::Annotation)
        target_type = case tag_obj.target
                      when Rugged::Commit then "rev"
                      when Rugged::Tag::Annotation then "rel"
                      when Rugged::Tree then "dir"
                      when Rugged::Blob then "cnt"
                      else "rev"
                      end

        metadata = {
          name: tag_obj.name,
          target: { hash: tag_obj.target.oid, type: target_type },
          message: tag_obj.message
        }

        if tag_obj.tagger
          metadata[:author] = format_person(tag_obj.tagger)
          metadata[:author_timestamp] = tag_obj.tagger[:time].to_i
          metadata[:author_timezone] = format_timezone(tag_obj.tagger[:time])
        end

        # Extract extra headers if present (like gpgsig for signed tags)
        extra_headers = extract_tag_extra_headers(repo, tag_obj)
        metadata[:extra_headers] = extra_headers unless extra_headers.empty?

        Swhid.from_release(metadata)
      else
        # Lightweight tag - points directly to commit
        raise ArgumentError, "Lightweight tags are not supported for release SWHIDs"
      end
    end

    def self.from_snapshot(repo_path)
      repo = Rugged::Repository.new(repo_path)
      branches = []

      # Check for HEAD first
      head_path = File.join(repo.path, "HEAD")
      if File.exist?(head_path)
        head_content = File.read(head_path).strip
        if head_content.start_with?("ref:")
          # HEAD is a symbolic ref
          target_ref = head_content.sub("ref: ", "")
          branches << {
            name: "HEAD",
            target_type: "alias",
            target: target_ref
          }
        end
      end

      # Get all references (branches and tags)
      repo.references.each do |ref|
        ref_name = ref.name

        if ref.type == :symbolic
          # This is an alias (symbolic ref)
          target_ref_name = ref.target
          branches << {
            name: ref_name,
            target_type: "alias",
            target: target_ref_name
          }
        else
          # Direct reference
          target_obj = ref.target

          # Determine target type and OID
          target_type, target_oid = case target_obj
                                     when Rugged::Commit
                                       ["revision", target_obj.oid]
                                     when Rugged::Tag::Annotation
                                       ["release", target_obj.oid]
                                     when Rugged::Tree
                                       ["directory", target_obj.oid]
                                     when Rugged::Blob
                                       ["content", target_obj.oid]
                                     else
                                       ["revision", target_obj.oid]
                                     end

          branches << {
            name: ref_name,
            target_type: target_type,
            target: target_oid
          }
        end
      end

      Swhid.from_snapshot(branches)
    end

    private

    def self.format_person(person)
      "#{person[:name]} <#{person[:email]}>"
    end

    def self.format_timezone(time)
      offset = time.utc_offset
      sign = offset >= 0 ? "+" : "-"
      hours = offset.abs / 3600
      minutes = (offset.abs % 3600) / 60
      format("%s%02d%02d", sign, hours, minutes)
    end

    def self.extract_extra_headers(repo, commit)
      # Rugged doesn't expose extra headers directly
      # We need to parse the raw commit object
      raw_data = repo.read(commit.oid).data
      lines = raw_data.split("\n")

      extra_headers = []
      in_headers = true

      lines.each do |line|
        # Stop when we hit the blank line before the message
        if line.empty?
          in_headers = false
          next
        end

        next unless in_headers

        # Skip standard headers
        next if line.start_with?("tree ", "parent ", "author ", "committer ")

        # Extract extra headers (like gpgsig, mergetag, svn-repo-uuid, etc)
        if line.start_with?(" ")
          # Continuation of previous header
          if extra_headers.any?
            extra_headers.last[1] += "\n#{line[1..]}"
          end
        elsif line.include?(" ")
          key, value = line.split(" ", 2)
          extra_headers << [key, value]
        end
      end

      extra_headers
    end

    def self.extract_tag_extra_headers(repo, tag)
      # Parse raw tag object for extra headers
      raw_data = repo.read(tag.oid).data
      lines = raw_data.split("\n")

      extra_headers = []
      in_headers = true

      lines.each do |line|
        # Stop when we hit the blank line before the message
        if line.empty?
          in_headers = false
          next
        end

        next unless in_headers

        # Skip standard tag headers
        next if line.start_with?("object ", "type ", "tag ", "tagger ")

        # Extract extra headers (like gpgsig for signed tags)
        if line.start_with?(" ")
          # Continuation of previous header
          if extra_headers.any?
            extra_headers.last[1] += "\n#{line[1..]}"
          end
        elsif line.include?(" ")
          key, value = line.split(" ", 2)
          extra_headers << [key, value]
        end
      end

      extra_headers
    end
  end
end
