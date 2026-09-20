# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Directory
      class Entry
        attr_reader :name, :type, :target, :perms

        def initialize(name:, type:, target:, perms: nil)
          @name = validate_name!(name)
          @type = type
          @target = target
          @perms = perms || default_perms
        end

        def default_perms
          case type
          when :dir
            "40000"
          when :file
            "100644"
          when :exec
            "100755"
          when :symlink
            "120000"
          when :rev
            "160000"
          else
            raise ValidationError, "Unknown entry type: #{type}"
          end
        end

        def sort_key
          type == :dir ? name.b + "/".b : name.b
        end

        def target_hash
          case target
          when String
            unless target.match?(/\A[0-9a-f]{#{OBJECT_ID_LENGTH}}\z/)
              raise ValidationError, "Invalid target hash"
            end
            [target].pack("H*")
          when Identifier
            [target.object_hash].pack("H*")
          else
            raise ValidationError, "Invalid target type"
          end
        end

        def validate_name!(value)
          raise ValidationError, "Directory entry name must be a string" unless value.is_a?(String)
          raise ValidationError, "Directory entry name cannot contain a null byte" if value.include?("\0")
          raise ValidationError, "Directory entry name cannot contain a slash" if value.include?("/")

          value
        end
      end

      def self.compute(entries)
        serialized = serialize_entries(entries)
        header = "tree #{serialized.bytesize}\0"
        hash = Digest::SHA1.hexdigest(header + serialized)

        Identifier.new(object_type: "dir", object_hash: hash)
      end

      def self.serialize_entries(entries)
        entries = entries.map do |entry_data|
          if entry_data.is_a?(Entry)
            entry_data
          else
            Entry.new(**entry_data)
          end
        end

        sorted_entries = entries.sort_by(&:sort_key)
        duplicate = sorted_entries.each_cons(2).find { |left, right| left.name.b == right.name.b }
        raise ValidationError, "Duplicate directory entry name: #{duplicate.first.name}" if duplicate

        sorted_entries.map do |entry|
          name_binary = entry.name.b
          perms_binary = entry.perms.to_s.b
          "#{perms_binary} #{name_binary}\0#{entry.target_hash}"
        end.join
      end

      def self.compute_hash(entries)
        compute(entries).object_hash
      end
    end
  end
end
