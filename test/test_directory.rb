# frozen_string_literal: true

require "test_helper"

class TestDirectory < Minitest::Test
  def test_empty_directory
    entries = []
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    # Hash of empty tree in Git
    assert_equal "4b825dc642cb6eb9a060e54bf8d69288fbee4904", swhid.object_hash
  end

  def test_single_file_entry
    entries = [
      { name: "file.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_multiple_entries
    entries = [
      { name: "a.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "b.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_directory_sorting
    # Directories should be sorted with trailing slash for comparison
    entries = [
      { name: "file", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" },
      { name: "dir", type: :dir, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid1 = Swhid.from_directory(entries)

    entries_reversed = entries.reverse
    swhid2 = Swhid.from_directory(entries_reversed)

    assert_equal swhid1.object_hash, swhid2.object_hash
  end

  def test_different_permissions
    entries = [
      { name: "script.sh", type: :exec, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_symlink_entry
    entries = [
      { name: "link", type: :symlink, target: "94a9ed024d3859793618152ea559a168bbcbb5e2" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_nested_directory
    entries = [
      { name: "subdir", type: :dir, target: "4b825dc642cb6eb9a060e54bf8d69288fbee4904" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end

  def test_custom_permissions
    entries = [
      { name: "file.txt", type: :file, target: "94a9ed024d3859793618152ea559a168bbcbb5e2", perms: "100644" }
    ]
    swhid = Swhid.from_directory(entries)

    assert_equal "dir", swhid.object_type
    assert_equal 40, swhid.object_hash.length
  end
end
