# frozen_string_literal: true

require "digest/sha1"

module Swhid
  module Objects
    class Content
      READ_SIZE = 64 * 1024

      def self.compute(data)
        data = data.to_s if data.is_a?(Symbol)

        header = "blob #{data.bytesize}\0"
        digest = Digest::SHA1.new
        digest.update(header)
        digest.update(data)

        Identifier.new(object_type: "cnt", object_hash: digest.hexdigest)
      end

      def self.compute_io(io, size:)
        unless size.is_a?(Integer) && size >= 0
          raise ArgumentError, "Content size must be a non-negative integer"
        end

        digest = Digest::SHA1.new
        digest.update("blob #{size}\0")

        bytes_read = 0
        buffer = String.new(capacity: READ_SIZE, encoding: Encoding::BINARY)
        while io.read(READ_SIZE, buffer)
          break if buffer.empty?

          bytes_read += buffer.bytesize
          digest.update(buffer)
        end

        unless bytes_read == size
          raise ArgumentError, "Content size is #{bytes_read} bytes, expected #{size}"
        end

        Identifier.new(object_type: "cnt", object_hash: digest.hexdigest)
      end

      def self.compute_hash(data)
        compute(data).object_hash
      end
    end
  end
end
