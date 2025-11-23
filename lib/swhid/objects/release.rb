# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Release
      OBJECT_TYPE_MAPPING = {
        "cnt" => "blob",
        "dir" => "tree",
        "rev" => "commit",
        "rel" => "tag",
        "snp" => "snapshot"
      }.freeze

      def self.compute(metadata)
        serialized = serialize_metadata(metadata)
        header = "tag #{serialized.bytesize}\0"
        hash = Digest::SHA1.hexdigest(header + serialized)

        Identifier.new(object_type: "rel", object_hash: hash)
      end

      def self.serialize_metadata(metadata)
        lines = []

        raise ValidationError, "Name is required" unless metadata[:name]
        raise ValidationError, "Target is required" unless metadata[:target]

        target_hash, target_type = extract_target(metadata[:target])
        lines << "object #{target_hash}"
        lines << "type #{target_type}"
        lines << "tag #{metadata[:name].gsub("\n", "\n ")}"

        if metadata[:author]
          raise ValidationError, "Author timestamp is required when author is present" unless metadata[:author_timestamp]

          author_line = format_person_line("tagger", metadata[:author], metadata[:author_timestamp], metadata[:author_timezone])
          lines << author_line
        end

        extra_headers = metadata[:extra_headers] || []
        extra_headers.each do |key, value|
          lines << format_header_line(key, value)
        end

        result = lines.join("\n") + "\n"

        if metadata[:message]
          result += "\n#{metadata[:message]}"
        end

        result
      end

      def self.format_person_line(prefix, person, timestamp, timezone)
        tz = timezone || "+0000"
        person_escaped = person.gsub("\n", "\n ")
        "#{prefix} #{person_escaped} #{timestamp} #{tz}"
      end

      def self.format_header_line(key, value)
        value_escaped = value.gsub("\n", "\n ")
        "#{key} #{value_escaped}"
      end

      def self.extract_target(target)
        case target
        when Hash
          hash = target[:hash] || target[:id]
          type = target[:type]
          raise ValidationError, "Target hash and type required" unless hash && type
          [hash, OBJECT_TYPE_MAPPING[type] || type]
        when Identifier
          [target.object_hash, OBJECT_TYPE_MAPPING[target.object_type] || target.object_type]
        else
          raise ValidationError, "Invalid target format"
        end
      end

      def self.compute_hash(metadata)
        compute(metadata).object_hash
      end
    end
  end
end
