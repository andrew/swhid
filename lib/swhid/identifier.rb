# frozen_string_literal: true

require "uri"

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
      raise ParseError, "Whitespace is not allowed in a SWHID" if swhid_string.match?(/\p{Space}/)

      core_part, qualifier_string = swhid_string.split(";", 2)

      parts = core_part.split(":", -1)
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

      raise ParseError, "Empty qualifier" if qualifier_string.empty?

      qualifier_string.split(";", -1).each do |part|
        raise ParseError, "Empty qualifier" if part.empty?

        key, value = part.split("=", 2)
        raise ParseError, "Invalid qualifier: #{part}" if key.nil? || key.empty? || value.nil?
        raise ParseError, "Duplicate qualifier: #{key}" if qualifiers.key?(key.to_sym)

        qualifiers[key.to_sym] = decode_qualifier_value(key, value)
      end

      qualifiers
    end

    def self.decode_qualifier_value(key, value)
      raise ParseError, "Invalid percent escape in #{key} qualifier" if value.match?(/%(?![0-9a-fA-F]{2})/)

      decoded = value.b.gsub(/%([0-9a-fA-F]{2})/) { [$1].pack("H2") }
      decoded.force_encoding(Encoding::UTF_8)
      return decoded if decoded.valid_encoding?

      raise ParseError, "Invalid UTF-8 in #{key} qualifier"
    end

    def format_qualifiers(quals)
      canonical_order = [:origin, :visit, :anchor, :path, :lines, :bytes]

      ordered_quals = canonical_order.map do |key|
        next unless quals.key?(key)

        value = quals[key]
        value = encode_qualifier_value(value, key) if key == :origin || key == :path
        "#{key}=#{value}"
      end.compact

      ordered_quals.join(";")
    end

    def encode_qualifier_value(value, key)
      pattern = key == :path ? /[%;?#\p{Space}]/ : /[%;\p{Space}]/
      value.to_s.gsub(pattern) { |character| character.bytes.map { |byte| "%%%02X" % byte }.join }
    end

    def validate_qualifiers!(qualifiers)
      unless qualifiers.respond_to?(:each_pair)
        raise ValidationError, "Qualifiers must be a hash"
      end

      validated = qualifiers.each_pair.each_with_object({}) do |(key, value), result|
        key = key.to_s
        unless %w[origin visit anchor path lines bytes].include?(key)
          raise ValidationError, "Invalid qualifier key: #{key}"
        end

        result[key.to_sym] = normalize_qualifier_value(key, value)
      end

      if validated.key?(:lines) && validated.key?(:bytes)
        raise ValidationError, "Lines and bytes cannot be combined"
      end
      if object_type != "cnt" && (validated.key?(:lines) || validated.key?(:bytes))
        raise ValidationError, "Fragment qualifiers require content"
      end
      if validated.key?(:path) && !%w[cnt dir].include?(object_type)
        raise ValidationError, "Path requires content or directory"
      end
      validated
    end

    def normalize_qualifier_value(key, value)
      string = value.to_s
      unless string.valid_encoding? && !string.match?(/\p{Cc}/)
        raise ValidationError, "Invalid characters in #{key} qualifier"
      end

      case key
      when "origin"
        uri = URI.parse(URI::RFC2396_PARSER.escape(string))
        raise ValidationError, "Origin must be an absolute URI" unless uri.absolute?
        string
      when "path"
        raise ValidationError, "Path must be absolute" unless string.start_with?("/")
        string
      when "visit", "anchor"
        parsed = value.is_a?(Identifier) ? value : Identifier.parse(string)
        unless parsed.qualifiers.empty?
          raise ValidationError, "Invalid #{key} qualifier: expected a core SWHID"
        end
        if key == "visit" && parsed.object_type != "snp"
          raise ValidationError, "Visit must identify a snapshot"
        end
        if key == "anchor" && parsed.object_type == "cnt"
          raise ValidationError, "Anchor cannot identify content"
        end
        parsed.core_swhid
      when "lines", "bytes"
        normalize_range_qualifier!(key, string)
      end
    rescue ParseError, URI::InvalidURIError
      raise ValidationError, "Invalid #{key} qualifier: #{value}"
    end

    def normalize_range_qualifier!(key, value)
      match = /\A(\d+)(?:-(\d+))?\z/.match(value)
      raise ValidationError, "Invalid #{key} qualifier: #{value}" unless match

      start_position = Integer(match[1], 10)
      end_position = match[2] && Integer(match[2], 10)
      max_position = (2**64) - 1

      minimum = key == "lines" ? 1 : 0
      if start_position < minimum || start_position > max_position || (end_position && (end_position < start_position || end_position > max_position))
        raise ValidationError, "Invalid #{key} qualifier: #{value}"
      end

      value
    end
  end
end
