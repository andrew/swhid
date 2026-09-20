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
          @name_binary = @name.b.freeze
          @perms_binary = @perms.to_s.b.freeze
          @target_hash = pack_target_hash(target).freeze
          @sort_key = type == :dir ? @name_binary + "/".b : @name_binary
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
          @sort_key
        end

        def target_hash
          @target_hash
        end

        def name_binary
          @name_binary
        end

        def perms_binary
          @perms_binary
        end

        def pack_target_hash(value)
          case value
          when String
            unless value.match?(/\A[0-9a-f]{#{OBJECT_ID_LENGTH}}\z/)
              raise ValidationError, "Invalid target hash"
            end
            [value].pack("H*")
          when Identifier
            [value.object_hash].pack("H*")
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
        digest = Digest::SHA1.new
        digest.update(header)
        digest.update(serialized)

        Identifier.new(object_type: "dir", object_hash: digest.hexdigest)
      end

      def self.serialize_entries(entries)
        entries = entries.map do |entry_data|
          if entry_data.is_a?(Entry)
            entry_data
          else
            Entry.new(**entry_data)
          end
        end

        entry_names = {}
        entries.each do |entry|
          name = entry.name_binary
          raise ValidationError, "Duplicate directory entry name: #{entry.name}" if entry_names.key?(name)

          entry_names[name] = true
        end

        sorted_entries = entries.sort_by(&:sort_key)

        capacity = sorted_entries.sum { |entry| entry.perms_binary.bytesize + entry.name_binary.bytesize + 22 }
        serialized = String.new(capacity: capacity, encoding: Encoding::BINARY)
        sorted_entries.each do |entry|
          serialized << entry.perms_binary << 32 << entry.name_binary << 0 << entry.target_hash
        end
        serialized
      end

      def self.compute_hash(entries)
        compute(entries).object_hash
      end
    end
  end
end
