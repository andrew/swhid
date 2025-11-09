# frozen_string_literal: true

require "test_helper"

class TestRelease < Minitest::Test
  def test_minimal_release
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" }
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_with_author
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" },
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_with_message
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" },
      message: "Release version 1.0.0"
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_with_timezone
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" },
      author: "John Doe <john@example.com>",
      author_timestamp: 1234567890,
      author_timezone: "+0200"
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_targeting_directory
    metadata = {
      name: "v1.0.0",
      target: { hash: "4b825dc642cb6eb9a060e54bf8d69288fbee4904", type: "dir" }
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_targeting_content
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "cnt" }
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_with_identifier_target
    target_identifier = Swhid::Identifier.new(
      object_type: "rev",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2"
    )
    metadata = {
      name: "v1.0.0",
      target: target_identifier
    }
    swhid = Swhid.from_release(metadata)

    assert_equal "rel", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_release_missing_name
    metadata = {
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" }
    }

    assert_raises(Swhid::ValidationError) do
      Swhid.from_release(metadata)
    end
  end

  def test_release_missing_target
    metadata = {
      name: "v1.0.0"
    }

    assert_raises(Swhid::ValidationError) do
      Swhid.from_release(metadata)
    end
  end

  def test_release_author_without_timestamp
    metadata = {
      name: "v1.0.0",
      target: { hash: "94a9ed024d3859793618152ea559a168bbcbb5e2", type: "rev" },
      author: "John Doe <john@example.com>"
    }

    assert_raises(Swhid::ValidationError) do
      Swhid.from_release(metadata)
    end
  end
end
