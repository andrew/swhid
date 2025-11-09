# frozen_string_literal: true

require "test_helper"

class TestSnapshot < Minitest::Test
  def test_empty_snapshot
    branches = []
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_single_branch
    branches = [
      { name: "refs/heads/main", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_multiple_branches
    branches = [
      { name: "refs/heads/main", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "refs/heads/develop", target_type: "revision", target: "84a9ed024d3859793618152ea559a168bbcbb5e1" }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_branch_sorting
    branches = [
      { name: "z-branch", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "a-branch", target_type: "revision", target: "84a9ed024d3859793618152ea559a168bbcbb5e1" }
    ]
    swhid1 = Swhid.from_snapshot(branches)

    branches_reversed = branches.reverse
    swhid2 = Swhid.from_snapshot(branches_reversed)

    assert_equal swhid1.object_hash, swhid2.object_hash
  end

  def test_alias_branch
    branches = [
      { name: "HEAD", target_type: "alias", target: "refs/heads/main" },
      { name: "refs/heads/main", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_dangling_branch
    branches = [
      { name: "refs/heads/old-branch", target_type: "dangling" }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_different_target_types
    branches = [
      { name: "refs/heads/main", target_type: "revision", target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "refs/tags/v1.0", target_type: "release", target: "84a9ed024d3859793618152ea559a168bbcbb5e1" },
      { name: "refs/heads/archive", target_type: "directory", target: "74a9ed024d3859793618152ea559a168bbcbb5e0" }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_branch_with_identifier_target
    target_identifier = Swhid::Identifier.new(
      object_type: "rev",
      object_hash: "94a9ed024d3859793618152ea559a168bbcbb5e2"
    )
    branches = [
      { name: "refs/heads/main", target_type: "revision", target: target_identifier }
    ]
    swhid = Swhid.from_snapshot(branches)

    assert_equal "snp", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end
end
