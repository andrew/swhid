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
      @qualifiers = qualifiers
    end

    def self.parse(swhid_string)
      raise ParseError, "SWHID string cannot be nil or empty" if swhid_string.nil? || swhid_string.empty?

      core_part, *qualifier_parts = swhid_string.split(";")

      parts = core_part.split(":")
      raise ParseError, "Invalid SWHID format" unless parts.length == 4

      scheme, version, object_type, object_hash = parts

      raise ParseError, "Invalid scheme: #{scheme}" unless scheme == SCHEME
      raise ParseError, "Invalid version: #{version}" unless version == SCHEME_VERSION.to_s

      qualifiers = parse_qualifiers(qualifier_parts)

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

    def self.parse_qualifiers(qualifier_parts)
      qualifiers = {}

      qualifier_parts.each do |part|
        key, value = part.split("=", 2)
        next if key.nil? || value.nil?

        qualifiers[key.to_sym] = decode_qualifier_value(value)
      end

      qualifiers
    end

    def self.decode_qualifier_value(value)
      URI.decode_www_form_component(value)
    end

    def format_qualifiers(quals)
      canonical_order = [:origin, :visit, :anchor, :path, :lines, :bytes]

      ordered_quals = canonical_order.map do |key|
        next unless quals.key?(key)

        "#{key}=#{encode_qualifier_value(quals[key])}"
      end.compact

      other_quals = quals.reject { |key, _| canonical_order.include?(key) }.map do |key, value|
        "#{key}=#{encode_qualifier_value(value)}"
      end

      (ordered_quals + other_quals).join(";")
    end

    def encode_qualifier_value(value)
      value.to_s.gsub(";", "%3B").gsub("%", "%25")
    end
  end
end
