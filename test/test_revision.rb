# frozen_string_literal: true

require "test_helper"

class TestRevision < Minitest::Test
  def test_minimal_revision
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890
    }
    swhid = Swhid.from_revision(metadata)

    assert_equal "rev", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_revision_with_message
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890,
      message: "Initial commit"
    }
    swhid = Swhid.from_revision(metadata)

    assert_equal "rev", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_revision_with_timezone
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      author_timezone: "+0100",
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890,
      committer_timezone: "-0500"
    }
    swhid = Swhid.from_revision(metadata)

    assert_equal "rev", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_revision_with_parents
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890,
      parents: [
        "94a9ed024d3859793618152ea559a168bbcbb5e2",
        "84a9ed024d3859793618152ea559a168bbcbb5e1"
      ]
    }
    swhid = Swhid.from_revision(metadata)

    assert_equal "rev", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_revision_with_extra_headers
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890,
      extra_headers: [
        ["encoding", "UTF-8"],
        ["gpgsig", "-----BEGIN PGP SIGNATURE-----"]
      ]
    }
    swhid = Swhid.from_revision(metadata)

    assert_equal "rev", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_revision_missing_directory
    metadata = {
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890
    }

    assert_raises(Swhid::ValidationError) do
      Swhid.from_revision(metadata)
    end
  end

  def test_revision_missing_author
    metadata = {
      directory: "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
      author_timestamp: 1234567890,
      committer: "Jane Smith <jane@example.com>",
      committer_timestamp: 1234567890
    }

    assert_raises(Swhid::ValidationError) do
      Swhid.from_revision(metadata)
    end
  end
end
