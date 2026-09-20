# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Snapshot
      class Branch
        attr_reader :name, :target_type, :target

        def initialize(name:, target_type:, target: nil)
          @name = validate_name!(name)
          @target_type = target_type
          @target = target
        end

        def serialize
          target_identifier = compute_target_identifier
          target_length = target_identifier.bytesize

          "#{target_type} #{name}\0#{target_length}:#{target_identifier}"
        end

        private

        def validate_name!(value)
          raise ValidationError, "Snapshot branch name must be a string" unless value.is_a?(String)
          raise ValidationError, "Snapshot branch name cannot contain a null byte" if value.include?("\0")

          value
        end

        def compute_target_identifier
          case target_type
          when "content", "directory", "revision", "release", "snapshot"
            extract_hash_bytes(target)
          when "alias"
            target.to_s.b
          when "dangling"
            "".b
          else
            raise ValidationError, "Invalid target type: #{target_type}"
          end
        end

        def extract_hash_bytes(value)
          hash_string = case value
                       when String
                         value.match?(/\A[0-9a-f]{#{OBJECT_ID_LENGTH}}\z/) ? value : nil
                       when Identifier
                         value.object_hash
                       else
                         nil
                       end

          raise ValidationError, "Invalid target hash" unless hash_string

          [hash_string].pack("H*")
        end
      end

      def self.compute(branches)
        serialized = serialize_branches(branches)
        header = "snapshot #{serialized.bytesize}\0"
        digest = Digest::SHA1.new
        digest.update(header)
        digest.update(serialized)

        Identifier.new(object_type: "snp", object_hash: digest.hexdigest)
      end

      def self.serialize_branches(branches)
        branch_objects = branches.map do |branch_data|
          if branch_data.is_a?(Branch)
            branch_data
          else
            Branch.new(**branch_data)
          end
        end

        sorted_branches = branch_objects.sort_by { |branch| branch.name.b }
        duplicate = sorted_branches.each_cons(2).find { |left, right| left.name.b == right.name.b }
        raise ValidationError, "Duplicate snapshot branch name: #{duplicate.first.name}" if duplicate

        sorted_branches.map(&:serialize).join
      end

      def self.compute_hash(branches)
        compute(branches).object_hash
      end
    end
  end
end
