# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Content
      def self.compute(data)
        data = data.to_s if data.is_a?(Symbol)
        data = data.b if data.respond_to?(:b)

        header = "blob #{data.bytesize}\0"
        hash = Digest::SHA1.hexdigest(header + data)

        Identifier.new(object_type: "cnt", object_hash: hash)
      end

      def self.compute_hash(data)
        compute(data).object_hash
      end
    end
  end
end
