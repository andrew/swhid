# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Directory
      class Entry
        attr_reader :name, :type, :target, :perms

        def initialize(name:, type:, target:, perms: nil)
          @name = name
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
          type == :dir ? "#{name}/" : name
        end

        def target_hash
          case target
          when String
            raise ValidationError, "Invalid hash length" unless target.length == 40
            [target].pack("H*")
          when Identifier
            [target.object_id].pack("H*")
          else
            raise ValidationError, "Invalid target type"
          end
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

        sorted_entries.map do |entry|
          # Convert name to binary UTF-8 to match target_hash encoding
          name_binary = entry.name.encode(Encoding::UTF_8).force_encoding(Encoding::BINARY)
          perms_binary = entry.perms.encode(Encoding::UTF_8).force_encoding(Encoding::BINARY)
          "#{perms_binary} #{name_binary}\0#{entry.target_hash}"
        end.join
      end

      def self.compute_hash(entries)
        compute(entries).object_hash
      end
    end
  end
end
