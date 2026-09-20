# frozen_string_literal: true

require "test_helper"
require "stringio"

class TestContent < Minitest::Test
  def test_compute_from_string
    content = "Hello, World!"
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
    assert swhid.object_hash =~ /\A[0-9a-f]{40}\z/
  end

  def test_compute_from_empty_string
    content = ""
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391", swhid.object_hash
  end

  def test_git_compatibility
    # This is the hash Git would produce for "test\n"
    content = "test\n"
    swhid = Swhid.from_content(content)

    # Git hash: echo -n "test" | git hash-object --stdin
    # The hash for "test\n" blob
    assert_equal "9daeafb9864cf43055ae93beb0afd6c7d144bfa4", swhid.object_hash
  end

  def test_content_with_null_bytes
    content = "hello\x00world"
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_compute_hash_method
    content = "Hello, World!"
    hash = Swhid::Objects::Content.compute_hash(content)

    assert_equal 40, hash.length
    assert hash =~ /\A[0-9a-f]{40}\z/
  end

  def test_binary_content
    content = "\xFF\xFE\xFD".b
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_large_content
    content = "x" * 10000
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_unicode_content
    content = "Hello 世界! 🌍"
    swhid = Swhid.from_content(content)

    assert_equal "cnt", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_compute_from_io
    content = ("streamed content\n" * 10_000).b

    from_string = Swhid.from_content(content)
    from_io = Swhid.from_content_io(StringIO.new(content), size: content.bytesize)

    assert_equal from_string, from_io
  end

  def test_compute_from_io_rejects_incorrect_size
    error = assert_raises(ArgumentError) do
      Swhid.from_content_io(StringIO.new("content"), size: 6)
    end

    assert_equal "Content size is 7 bytes, expected 6", error.message
  end
end
