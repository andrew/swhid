# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Revision
      def self.compute(metadata)
        serialized = serialize_metadata(metadata)
        header = "commit #{serialized.bytesize}\0"
        hash = Digest::SHA1.hexdigest(header + serialized)

        Identifier.new(object_type: "rev", object_hash: hash)
      end

      def self.serialize_metadata(metadata)
        lines = []

        directory = extract_hash(metadata[:directory])
        raise ValidationError, "Directory is required" unless directory
        lines << "tree #{directory}"

        parents = Array(metadata[:parents] || [])
        parents.each do |parent|
          parent_hash = extract_hash(parent)
          lines << "parent #{parent_hash}"
        end

        raise ValidationError, "Author is required" unless metadata[:author]
        raise ValidationError, "Author timestamp is required" unless metadata[:author_timestamp]

        author_line = format_person_line("author", metadata[:author], metadata[:author_timestamp], metadata[:author_timezone])
        lines << author_line

        raise ValidationError, "Committer is required" unless metadata[:committer]
        raise ValidationError, "Committer timestamp is required" unless metadata[:committer_timestamp]

        committer_line = format_person_line("committer", metadata[:committer], metadata[:committer_timestamp], metadata[:committer_timezone])
        lines << committer_line

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

      def self.extract_hash(value)
        case value
        when String
          value.length == 40 ? value : nil
        when Identifier
          value.object_hash
        else
          nil
        end
      end

      def self.compute_hash(metadata)
        compute(metadata).object_hash
      end
    end
  end
end
