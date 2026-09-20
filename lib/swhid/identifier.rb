# frozen_string_literal: true

module Swhid
  class Identifier
    attr_reader :scheme, :version, :object_type, :object_hash, :qualifiers

    def initialize(object_type:, object_hash:, qualifiers: {})
      @scheme = SCHEME
      @version = SCHEME_VERSION
      @object_type = validate_object_type!(object_type)
      @object_hash = validate_object_hash!(object_hash)
      @qualifiers = validate_qualifiers!(qualifiers)
    end

    def self.parse(swhid_string)
      raise ParseError, "SWHID string cannot be nil or empty" if swhid_string.nil? || swhid_string.empty?

      core_part, qualifier_string = swhid_string.split(";", 2)

      parts = core_part.split(":")
      raise ParseError, "Invalid SWHID format" unless parts.length == 4

      scheme, version, object_type, object_hash = parts

      raise ParseError, "Invalid scheme: #{scheme}" unless scheme == SCHEME
      raise ParseError, "Invalid version: #{version}" unless version == SCHEME_VERSION.to_s

      qualifiers = parse_qualifiers(qualifier_string)

      new(object_type: object_type, object_hash: object_hash, qualifiers: qualifiers)
    end

    def to_s
      core = "#{scheme}:#{version}:#{object_type}:#{object_hash}"
      return core if qualifiers.empty?

      qualifier_string = format_qualifiers(qualifiers)
      "#{core};#{qualifier_string}"
    end

    def core_swhid
      "#{scheme}:#{version}:#{object_type}:#{object_hash}"
    end

    def ==(other)
      return false unless other.is_a?(Identifier)

      core_swhid == other.core_swhid && qualifiers == other.qualifiers
    end

    def hash
      [core_swhid, qualifiers].hash
    end

    def eql?(other)
      self == other
    end

    private

    def validate_object_type!(type)
      unless VALID_OBJECT_TYPES.include?(type)
        raise ValidationError, "Invalid object type: #{type}. Must be one of: #{VALID_OBJECT_TYPES.join(", ")}"
      end
      type
    end

    def validate_object_hash!(hash)
      unless hash =~ /\A[0-9a-f]{#{OBJECT_ID_LENGTH}}\z/
        raise ValidationError, "Invalid object hash: #{hash}. Must be #{OBJECT_ID_LENGTH} hex digits"
      end
      hash
    end

    def self.parse_qualifiers(qualifier_string)
      qualifiers = {}
      return qualifiers unless qualifier_string

      qualifier_string.split(";", -1).each do |part|
        next if part.empty?

        key, value = part.split("=", 2)
        raise ParseError, "Invalid qualifier: #{part}" if key.nil? || key.empty? || value.nil?

        qualifiers[key.to_sym] = if key == "origin" || key == "path"
                                    decode_qualifier_value(key, value)
                                  else
                                    value
                                  end
      end

      qualifiers
    end

    def self.decode_qualifier_value(key, value)
      decoded = value.gsub(/%([0-9a-fA-F]{2})/) { [$1].pack("H2") }
      decoded.force_encoding(Encoding::UTF_8)
      return decoded if decoded.valid_encoding?

      raise ParseError, "Invalid UTF-8 in #{key} qualifier"
    end

    def format_qualifiers(quals)
      canonical_order = [:origin, :visit, :anchor, :path, :lines, :bytes]

      ordered_quals = canonical_order.map do |key|
        next unless quals.key?(key)

        value = quals[key]
        value = encode_qualifier_value(value) if key == :origin || key == :path
        "#{key}=#{value}"
      end.compact

      other_quals = quals.reject { |key, _| canonical_order.include?(key) }.map do |key, value|
        "#{key}=#{value}"
      end

      (ordered_quals + other_quals).join(";")
    end

    def encode_qualifier_value(value)
      value.to_s.gsub(";", "%3B")
    end

    def validate_qualifiers!(qualifiers)
      unless qualifiers.respond_to?(:each_pair)
        raise ValidationError, "Qualifiers must be a hash"
      end

      qualifiers.each_pair.each_with_object({}) do |(key, value), validated|
        key = key.to_s
        unless key.match?(/\A[^;=]+\z/)
          raise ValidationError, "Invalid qualifier key: #{key}"
        end

        validated[key.to_sym] = normalize_qualifier_value(key, value)
      end
    end

    def normalize_qualifier_value(key, value)
      case key
      when "origin", "path"
        string = value.to_s
        raise ValidationError, "Invalid UTF-8 in #{key} qualifier" unless string.valid_encoding?
        string
      when "visit", "anchor"
        parsed = value.is_a?(Identifier) ? value : Identifier.parse(value.to_s)
        unless parsed.qualifiers.empty?
          raise ValidationError, "Invalid #{key} qualifier: expected a core SWHID"
        end
        parsed.core_swhid
      when "lines", "bytes"
        normalize_range_qualifier!(key, value.to_s)
      else
        value
      end
    rescue ParseError, ValidationError
      raise ValidationError, "Invalid #{key} qualifier: #{value}"
    end

    def normalize_range_qualifier!(key, value)
      match = /\A(\d+)(?:-(\d+))?\z/.match(value)
      raise ValidationError, "Invalid #{key} qualifier: #{value}" unless match

      start_position = Integer(match[1], 10)
      end_position = match[2] && Integer(match[2], 10)
      max_position = (2**64) - 1

      if start_position > max_position || (end_position && (end_position < start_position || end_position > max_position))
        raise ValidationError, "Invalid #{key} qualifier: #{value}"
      end

      end_position ? "#{start_position}-#{end_position}" : start_position.to_s
    end
  end
end
