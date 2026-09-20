# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module FromGit
    def self.from_revision(repo_path, ref = "HEAD")
      repo = open_repository(repo_path)
      commit = repo.rev_parse(ref)

      raise ArgumentError, "Reference #{ref} is not a commit" unless commit.is_a?(Rugged::Commit)

      verify_git_object!(repo, commit.oid, :commit)
      Identifier.new(object_type: "rev", object_hash: commit.oid)
    end

    def self.from_release(repo_path, tag_name)
      repo = open_repository(repo_path)
      tag_ref = repo.references["refs/tags/#{tag_name}"]

      raise ArgumentError, "Tag #{tag_name} not found" unless tag_ref

      tag_obj = repo.lookup(tag_ref.target_id)

      if tag_obj.is_a?(Rugged::Tag::Annotation)
        verify_git_object!(repo, tag_obj.oid, :tag)
        Identifier.new(object_type: "rel", object_hash: tag_obj.oid)
      else
        raise ArgumentError, "Lightweight tags are not supported for release SWHIDs"
      end
    end

    def self.from_snapshot(repo_path)
      repo = open_repository(repo_path)
      branches = []
      target_cache = {}

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

      repo.references.each do |ref|
        ref_name = ref.name
        next unless ref_name.start_with?("refs/heads/", "refs/tags/")

        if ref.type == :symbolic
          target_ref_name = ref.target
          branches << {
            name: ref_name,
            target_type: "alias",
            target: target_ref_name
          }
        else
          target_oid = ref.target_id
          target_type = target_cache[target_oid] ||= reference_target_type(repo, target_oid)

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

    def self.open_repository(repo_path)
      require "rugged"
      Rugged::Repository.new(repo_path)
    end

    def self.verify_git_object!(repo, oid, expected_type)
      object = repo.read(oid)
      unless object.type == expected_type
        raise ValidationError, "Expected #{expected_type} object, found #{object.type}"
      end

      digest = Digest::SHA1.new
      digest.update("#{object.type} #{object.len}\0")
      digest.update(object.data)
      raise ValidationError, "Git object hash mismatch: #{oid}" unless digest.hexdigest == oid
    end

    def self.reference_target_type(repo, oid)
      case repo.read_header(oid)[:type]
      when :commit then "revision"
      when :tag then "release"
      when :tree then "directory"
      when :blob then "content"
      else "revision"
      end
    end
  end
end
