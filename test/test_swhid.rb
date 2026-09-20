# frozen_string_literal: true

require "test_helper"

class TestSwhid < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Swhid::VERSION
  end

  def test_parse_valid_core_swhid
    swhid_string = "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2"
    swhid = Swhid.parse(swhid_string)

    assert_equal "swh", swhid.scheme
    assert_equal 1, swhid.version
    assert_equal "cnt", swhid.object_type
    assert_equal "94a9ed024d3859793618152ea559a168bbcbb5e2", swhid.object_hash
    assert_empty swhid.qualifiers
  end

  def test_parse_swhid_with_qualifiers
    swhid_string = "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=https://example.com;lines=5-10"
    swhid = Swhid.parse(swhid_string)

    assert_equal "cnt", swhid.object_type
    assert_equal "https://example.com", swhid.qualifiers[:origin]
    assert_equal "5-10", swhid.qualifiers[:lines]
  end

  def test_parse_qualifiers_preserves_plus_and_decodes_semicolon
    swhid = Swhid.parse(
      "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=a+b%3Bc;path=/a%3Bb"
    )

    assert_equal "a+b;c", swhid.qualifiers[:origin]
    assert_equal "/a;b", swhid.qualifiers[:path]
    assert_equal(
      "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=a+b%3Bc;path=/a%3Bb",
      swhid.to_s
    )
  end

  def test_parse_rejects_qualifier_without_value
    assert_raises(Swhid::ParseError) do
      Swhid.parse("swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;broken")
    end
  end

  def test_parse_rejects_invalid_range_qualifiers
    %w[lines=20-10 lines=nope bytes=10- bytes=-10].each do |qualifier|
      assert_raises(Swhid::ValidationError) do
        Swhid.parse("swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;#{qualifier}")
      end
    end
  end

  def test_parse_canonicalizes_range_qualifiers
    swhid = Swhid.parse(
      "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;lines=001-002;bytes=000"
    )

    assert_equal "1-2", swhid.qualifiers[:lines]
    assert_equal "0", swhid.qualifiers[:bytes]
    assert_equal(
      "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;lines=1-2;bytes=0",
      swhid.to_s
    )
  end

  def test_parse_rejects_invalid_swhid_qualifiers
    %w[visit anchor].each do |qualifier|
      assert_raises(Swhid::ValidationError) do
        Swhid.parse("swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;#{qualifier}=invalid")
      end
    end
  end

  def test_parse_invalid_scheme
    assert_raises(Swhid::ParseError) do
      Swhid.parse("invalid:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2")
    end
  end

  def test_parse_invalid_version
    assert_raises(Swhid::ParseError) do
      Swhid.parse("swh:2:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2")
    end
  end

  def test_parse_invalid_object_type
    assert_raises(Swhid::ValidationError) do
      Swhid.parse("swh:1:invalid:94a9ed024d3859793618152ea559a168bbcbb5e2")
    end
  end

  def test_parse_invalid_object_id
    assert_raises(Swhid::ValidationError) do
      Swhid.parse("swh:1:cnt:invalid")
    end
  end

  def test_to_s_without_qualifiers
    swhid = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2"
    )

    assert_equal "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2", swhid.to_s
  end

  def test_to_s_with_qualifiers
    swhid = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2",
      qualifiers: { origin: "https://example.com", lines: "5-10" }
    )

    assert_equal "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;origin=https://example.com;lines=5-10", swhid.to_s
  end

  def test_to_s_encodes_qualifier_semicolon_once
    swhid = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2",
      qualifiers: { path: "/a;b" }
    )

    assert_equal "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2;path=/a%3Bb", swhid.to_s
  end

  def test_core_swhid
    swhid = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2",
      qualifiers: { origin: "https://example.com" }
    )

    assert_equal "swh:1:cnt:94a9ed024d3859793618152ea559a168bbcbb5e2", swhid.core_swhid
  end

  def test_equality
    swhid1 = Swhid::Identifier.new(object_type: "cnt", object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2")
    swhid2 = Swhid::Identifier.new(object_type: "cnt", object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2")

    assert_equal swhid1, swhid2
  end

  def test_inequality_different_qualifiers
    swhid1 = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2",
      qualifiers: { origin: "https://example.com" }
    )
    swhid2 = Swhid::Identifier.new(
      object_type: "cnt",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2"
    )

    refute_equal swhid1, swhid2
  end
end
