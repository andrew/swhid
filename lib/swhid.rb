# frozen_string_literal: true

require_relative "swhid/version"
require_relative "swhid/identifier"
require_relative "swhid/objects/content"
require_relative "swhid/objects/directory"
require_relative "swhid/objects/revision"
require_relative "swhid/objects/release"
require_relative "swhid/objects/snapshot"
require_relative "swhid/from_filesystem"

module Swhid
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end

  SCHEME = "swh"
  SCHEME_VERSION = 1
  VALID_OBJECT_TYPES = %w[cnt dir rev rel snp].freeze
  OBJECT_ID_LENGTH = 40

  def self.parse(swhid_string)
    Identifier.parse(swhid_string)
  end

  def self.from_content(content)
    Objects::Content.compute(content)
  end

  def self.from_directory(entries)
    Objects::Directory.compute(entries)
  end

  def self.from_revision(metadata)
    Objects::Revision.compute(metadata)
  end

  def self.from_release(metadata)
    Objects::Release.compute(metadata)
  end

  def self.from_snapshot(branches)
    Objects::Snapshot.compute(branches)
  end
end
