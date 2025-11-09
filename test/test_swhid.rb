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
