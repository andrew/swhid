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

      # Extract extra headers if present
      extra_headers = extract_extra_headers(commit)
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

        Swhid.from_release(metadata)
      else
        # Lightweight tag - points directly to commit
        raise ArgumentError, "Lightweight tags are not supported for release SWHIDs"
      end
    end

    def self.from_snapshot(repo_path)
      repo = Rugged::Repository.new(repo_path)
      branches = []

      # Get all references (branches and tags)
      repo.references.each do |ref|
        ref_name = ref.name

        if ref.type == :symbolic
          # This is an alias (like HEAD pointing to refs/heads/main)
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

    def self.extract_extra_headers(commit)
      # Rugged doesn't expose extra headers directly
      # We would need to parse the raw commit object for this
      # For now, return empty array
      []
    end
  end
end
